class HotwireLabController < ApplicationController
  before_action :require_authentication

  TECHNIQUES = {
    "turbo_drive" => {
      name: "Turbo Drive (Whole-Page SPA Speed)",
      icon: "🚗",
      summary: "Intercepts all link clicks and form submissions, fetches HTML in background, merges <head>, and replaces <body> without full browser reload.",
      dom_effect: "Replaces <body>. Keeps window and JavaScript environment alive.",
      code: "<a href=\"/dashboard\">Dashboard</a>\n# Intercepted automatically! Zero custom JavaScript."
    },
    "turbo_frames" => {
      name: "Turbo Frames (Scoped Sub-trees)",
      icon: "🖼️",
      summary: "Deconstructs pages into independent, lazily-loaded or independently updated contexts. Interactions inside a frame stay inside the frame.",
      dom_effect: "Only matches matching <turbo-frame id=\"...\">. Rest of page remains untouched.",
      code: "<%= turbo_frame_tag \"cart_items\" do %>\n  <%= render @cart_items %>\n<% end %>"
    },
    "turbo_streams" => {
      name: "Turbo Streams (Targeted DOM Mutation)",
      icon: "⚡",
      summary: "Delivers granular DOM updates across 7 actions: append, prepend, replace, update, remove, before, after — via HTTP responses or WebSockets.",
      dom_effect: "Exact targeted DOM mutations without re-rendering the surrounding template.",
      code: "<turbo-stream action=\"append\" target=\"messages\">\n  <template><%= render @message %></template>\n</turbo-stream>"
    },
    "turbo_morph" => {
      name: "Turbo Morphing (Idiomorph Preservation)",
      icon: "🧬",
      summary: "Intelligently morphs existing DOM trees using Idiomorph instead of replacing them. Preserves form inputs, focus, and scroll positions.",
      dom_effect: "Diffs DOM nodes, changes only dirty attributes and text nodes.",
      code: "# In controller\nclass PostsController < ApplicationController\n  # Enables morphing for stream actions\nend"
    },
    "stimulus" => {
      name: "Stimulus Lifecycle (HTML-Augmented JS)",
      icon: "🔌",
      summary: "A modest JavaScript framework designed to enhance server-rendered HTML. Connects JavaScript objects to HTML elements using data-* attributes.",
      dom_effect: "connect() fires when element enters DOM; disconnect() when removed.",
      code: "<div data-controller=\"counter\">\n  <button data-action=\"click->counter#increment\">+</button>\n  <span data-counter-target=\"display\">0</span>\n</div>"
    }
  }.freeze

  def show
    @active_technique = params[:tech].presence || "turbo_drive"
    @technique_data = TECHNIQUES[@active_technique] || TECHNIQUES["turbo_drive"]
    load_lab
  end

  # Grades a prediction. The learner has to commit to an answer before seeing
  # the result, which is the whole point: Turbo's actions are easy to read
  # about and easy to get wrong.
  def predict
    load_lab
    @scenario = Hotwire::Scenarios.find(params[:slug])
    return redirect_to hotwire_lab_path unless @scenario

    @chosen = params[:prediction].to_s
    @correct = Hotwire::Scenarios.correct?(@scenario, @chosen)
    @revealed = true

    notice = @correct ? award(@scenario) : nil
    mark_attempted(@scenario, correct: @correct)
    load_lab

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice if notice }
      format.html { redirect_to hotwire_lab_path(tech: @active_technique), notice: notice }
    end
  end

  # Runs the chosen action for real: the response below is an actual
  # <turbo-stream> carrying it, so the DOM the learner is looking at is
  # changed by the mechanism being taught rather than a drawing of it.
  def operate
    load_lab

    result = Hotwire::StreamEngine.apply(
      @playground,
      action: params[:action_name],
      target: params[:target].presence || Hotwire::StreamEngine::CONTAINER_ID,
      content: { "id" => "msg_#{rand(100..999)}", "text" => params[:text].presence || "New message" }
    )

    @stream_error = result.error
    session[:hotwire_playground] = result.items
    @playground = result.items

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to hotwire_lab_path }
    end
  end

  def reset
    session[:hotwire_playground] = nil
    session[:hotwire_attempts] = nil
    redirect_to hotwire_lab_path, notice: "Playground and predictions reset."
  end

  private

  def load_lab
    session[:hotwire_playground] ||= Hotwire::Scenarios::START.map(&:dup)
    @playground = session[:hotwire_playground]
    @attempts = session[:hotwire_attempts] || {}

    @scenarios = Hotwire::Scenarios.all
    @solved_slugs = solved_slugs
    @active_technique ||= "turbo_drive"
  end

  # Which scenarios this learner has demonstrated. Read from the XP ledger
  # rather than the session, so a solved prediction survives a new browser
  # and cannot be un-solved by clearing cookies.
  def solved_slugs
    keys = Hotwire::Scenarios.slugs.map { |slug| "lab:hotwire_lab:#{slug}" }
    current_user.xp_transactions.where(idempotency_key: keys)
                .pluck(:idempotency_key)
                .map { |key| key.split(":").last }
                .to_set
  end

  def award(scenario)
    outcome = Labs::Completion.new(
      user: current_user, lab_key: "hotwire_lab",
      xp: scenario[:xp_reward],
      reason: "Hotwire Lab: #{scenario[:title]}",
      detail: scenario[:slug]
    ).call

    return nil unless outcome.xp.positive?

    "⚡ Correct — #{scenario[:title]} (+#{outcome.xp} XP)"
  end

  # A wrong prediction still counts as practice against the prediction
  # dimension, so guessing lowers the running score rather than costing
  # nothing.
  def mark_attempted(scenario, correct:)
    attempts = session[:hotwire_attempts] || {}
    attempts[scenario[:slug]] = (attempts[scenario[:slug]].to_i + 1)
    session[:hotwire_attempts] = attempts

    return if correct

    skill = Labs::Catalogue.skill_for("hotwire_lab")
    return if skill.nil?

    Mastery::Recorder.new(
      user: current_user, skill: skill, dimension: :prediction,
      score: 0, correct: false
    ).call
  end
end
