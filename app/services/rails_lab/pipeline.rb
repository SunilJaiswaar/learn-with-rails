module RailsLab
  # Traces one request through the Rails stack (spec 109).
  #
  # Each stage reports what it received, what it added, and what it handed on,
  # so the learner can see where a value first appears — params gaining a key
  # the query string never had, a 404 being decided by the router rather than
  # the controller, a flash disappearing after exactly one redirect.
  #
  # Conditions let the request fail in a specific, named way. The point is that
  # the *stage* that reacts is the lesson: a missing CSRF token is refused in
  # the controller, an unknown path dies at the router, and a throttled request
  # never reaches either.
  class Pipeline
    STAGES = %i[
      web_server middleware router controller model database view response
    ].freeze

    CONDITIONS = {
      "unknown_path" => {
        label: "No route matches the path",
        stops_at: :router,
        status: 404,
        because: "The router raises ActionController::RoutingError before any " \
                 "controller is involved. Your code never runs, which is why " \
                 "a typo'd path cannot be fixed in a controller."
      },
      "missing_csrf" => {
        label: "POST with no CSRF token",
        stops_at: :controller,
        status: 422,
        because: "protect_from_forgery runs as a controller callback, so the " \
                 "request has already been routed and the session loaded. The " \
                 "action itself is never called."
      },
      "record_not_found" => {
        label: "The record does not exist",
        stops_at: :model,
        status: 404,
        because: "ActiveRecord::RecordNotFound is raised in the model layer and " \
                 "rescued into a 404 by ActionDispatch::ShowExceptions. The " \
                 "view is never rendered."
      },
      "throttled" => {
        label: "Over the rate limit",
        stops_at: :middleware,
        status: 429,
        because: "Rack::Attack sits in the middleware stack, so a throttled " \
                 "request is refused before routing. Nothing in your " \
                 "application is executed — which is the point of putting it " \
                 "there."
      },
      "not_authenticated" => {
        label: "No signed-in session",
        stops_at: :controller,
        status: 302,
        because: "The session cookie is decoded by middleware, but the decision " \
                 "to redirect is a controller callback. That is why an " \
                 "unauthenticated request still costs you a routed request."
      },
      "slow_query" => {
        label: "The query is slow (no index)",
        stops_at: nil,
        status: 200,
        because: "Nothing fails. The request completes, 1,400ms later, and the " \
                 "only evidence is the database time in the log line. This is " \
                 "the failure mode that does not announce itself."
      }
    }.freeze

    Stage = Struct.new(:key, :name, :reached, :detail, :adds, :timing_ms,
                       keyword_init: true) do
      def reached?
        reached
      end
    end

    Result = Struct.new(:stages, :status, :condition, :verb, :path,
                        :params, :total_ms, keyword_init: true) do
      def stopped_at
        stages.find { |stage| !stage.reached? }
      end

      def completed?
        stages.all?(&:reached?)
      end

      def because
        condition && Pipeline::CONDITIONS.dig(condition, :because)
      end
    end

    def initialize(verb: "GET", path: "/skills/sql-joins", condition: nil, query: nil)
      @verb = verb.to_s.upcase
      @path = path.to_s.presence || "/"
      @condition = CONDITIONS.key?(condition.to_s) ? condition.to_s : nil
      @query = query.to_s
    end

    def call
      stops_at = @condition && CONDITIONS.dig(@condition, :stops_at)
      halted = false

      stages = STAGES.map do |key|
        reached = !halted
        halted = true if key == stops_at
        build_stage(key, reached: reached, halts_here: key == stops_at)
      end

      Result.new(
        stages: stages, status: status, condition: @condition,
        verb: @verb, path: @path, params: params,
        total_ms: stages.select(&:reached?).sum { |s| s.timing_ms }
      )
    end

    # The params hash as Rails assembles it, which is the union of three
    # sources — the single most common surprise for a learner reading
    # `params` and not finding where a key came from.
    def params
      merged = { "controller" => controller_name, "action" => action_name }
      merged["id"] = path_id if path_id
      query_params.each { |k, v| merged[k] = v }
      merged
    end

    private

    def status
      return CONDITIONS.dig(@condition, :status) if @condition

      @verb == "POST" ? 302 : 200
    end

    def query_params
      return {} if @query.blank?

      @query.delete_prefix("?").split("&").filter_map do |pair|
        key, value = pair.split("=", 2)
        [ key, value.to_s ] if key.present?
      end.to_h
    end

    def segments
      @segments ||= @path.split("/").reject(&:blank?)
    end

    def controller_name
      segments.first.presence || "home"
    end

    def path_id
      segments[1]
    end

    def action_name
      return "create" if @verb == "POST"
      return "show" if path_id

      "index"
    end

    def build_stage(key, reached:, halts_here:)
      spec = stage_spec(key)
      Stage.new(
        key: key,
        name: spec[:name],
        reached: reached,
        detail: halts_here ? halt_detail(key) : spec[:detail],
        adds: reached ? spec[:adds] : [],
        timing_ms: reached ? timing_for(key) : 0
      )
    end

    def halt_detail(key)
      "Stopped here: #{CONDITIONS.dig(@condition, :label)}. " \
        "#{stage_spec(key)[:name]} answered #{status} and nothing downstream ran."
    end

    def stage_spec(key)
      case key
      when :web_server
        { name: "Puma",
          detail: "Accepts the socket, parses the HTTP request into a Rack env " \
                  "hash, and hands it to the app on a thread from the pool.",
          adds: [ "rack.input", "REQUEST_METHOD = #{@verb}", "PATH_INFO = #{@path}" ] }
      when :middleware
        { name: "Middleware (#{MiddlewareStack.count})",
          detail: "Each layer may read the env, change it, answer early, or " \
                  "pass it down. Everything here runs before your router.",
          adds: [ "X-Request-Id", "cookies", "session", "flash", "CSP nonce" ] }
      when :router
        { name: "Router",
          detail: "Matches #{@verb} #{@path} against routes.rb top to bottom and " \
                  "decides which controller and action — or raises if nothing matches.",
          adds: [ "params[:controller] = #{controller_name}",
                  "params[:action] = #{action_name}",
                  path_id ? "params[:id] = #{path_id}" : nil ].compact }
      when :controller
        { name: "Controller",
          detail: "Runs before_action callbacks in order, then the action. " \
                  "Authentication, authorisation and CSRF all live here.",
          adds: [ "@ivars for the view", "strong parameters applied" ] }
      when :model
        { name: "Model (Active Record)",
          detail: "Builds a relation. Nothing has touched the database yet — a " \
                  "relation is lazy until something enumerates it.",
          adds: [ "an unexecuted Relation" ] }
      when :database
        { name: "PostgreSQL",
          detail: slow? ? "The query runs without a usable index: a sequential " \
                          "scan over every row." \
                        : "The query runs and rows come back over the " \
                          "connection checked out for this request.",
          adds: [ slow? ? "1,400ms of database time" : "12ms of database time" ] }
      when :view
        { name: "View",
          detail: "Renders the template and layout to a String. Every " \
                  "`<%= %>` is HTML-escaped unless you ask otherwise.",
          adds: [ "response body", "ETag (from the body digest)" ] }
      when :response
        { name: "Response",
          detail: "The status, headers and body travel back out through every " \
                  "middleware in reverse order, which is when ETag and " \
                  "X-Runtime are attached.",
          adds: [ "status #{status}", "Content-Type", "X-Runtime", "ETag" ] }
      end
    end

    def slow?
      @condition == "slow_query"
    end

    def timing_for(key)
      base = { web_server: 1, middleware: 3, router: 1, controller: 2,
               model: 1, database: 12, view: 8, response: 1 }
      return 1_400 if key == :database && slow?

      base.fetch(key, 1)
    end
  end
end
