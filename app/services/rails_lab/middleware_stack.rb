module RailsLab
  # The middleware stack of *this* application, annotated.
  #
  # Spec 109 asks for a Rails request to be inspectable at every step so Rails
  # reads as a machine rather than a list of APIs. Reading the stack from
  # Rails.application rather than hardcoding it means the lesson cannot drift
  # from the application the learner is running — and it is how this lab found
  # that Rack::Attack was registered twice.
  module MiddlewareStack
    # What each middleware actually does, in one line, plus the observable
    # evidence it leaves behind. Anything in the real stack without an entry
    # here still renders, labelled as undocumented, rather than being hidden.
    NOTES = {
      "Rack::Sendfile" => {
        does: "Hands large file responses to the web server to send directly.",
        evidence: "X-Sendfile-Type request header; no change in development."
      },
      "ActionDispatch::Static" => {
        does: "Serves files out of public/ before the router ever runs.",
        evidence: "A request for an existing public file never reaches your code."
      },
      "Propshaft::Server" => {
        does: "Serves compiled assets under /assets.",
        evidence: "Asset URLs carry a digest so they can be cached forever."
      },
      "ActionDispatch::Executor" => {
        does: "Wraps the request so Rails can reload code and return connections.",
        evidence: "Autoloading in development; connection checkout per request."
      },
      "ActiveSupport::Cache::Strategy::LocalCache" => {
        does: "Gives the request its own in-memory cache layer.",
        evidence: "Reading the same cache key twice in one request hits memory."
      },
      "Rack::Runtime" => {
        does: "Times the request.",
        evidence: "X-Runtime response header."
      },
      "Rack::MethodOverride" => {
        does: "Turns a POST carrying _method=patch into a PATCH.",
        evidence: "Why Rails forms can PATCH and DELETE from an HTML form."
      },
      "ActionDispatch::RequestId" => {
        does: "Assigns a unique id to the request.",
        evidence: "X-Request-Id response header; ties log lines together."
      },
      "ActionDispatch::RemoteIp" => {
        does: "Works out the client IP from the forwarding headers.",
        evidence: "request.remote_ip, which is not the same as REMOTE_ADDR."
      },
      "Rails::Rack::Logger" => {
        does: "Starts the request log and tags it.",
        evidence: "The 'Started GET ...' line."
      },
      "ActionDispatch::ShowExceptions" => {
        does: "Turns an uncaught exception into an error page in production.",
        evidence: "A 500 page instead of a crashed connection."
      },
      "ActionDispatch::DebugExceptions" => {
        does: "Renders the development error page with the backtrace.",
        evidence: "The familiar development stack-trace screen."
      },
      "ActionDispatch::ActionableExceptions" => {
        does: "Adds the buttons on error pages that run a fix for you.",
        evidence: "'Run pending migrations' on the migration error page."
      },
      "ActionDispatch::Callbacks" => {
        does: "Runs to_prepare callbacks around the request.",
        evidence: "Mostly invisible; used by engines and reloading."
      },
      "ActionDispatch::Cookies" => {
        does: "Parses the Cookie header and signs or encrypts what you set.",
        evidence: "cookies and cookies.signed become available."
      },
      "ActionDispatch::Session::CookieStore" => {
        does: "Loads the session out of a signed, encrypted cookie.",
        evidence: "session works — and is capped at 4KB, because it is a cookie."
      },
      "ActionDispatch::Flash" => {
        does: "Moves flash out of the session into this request, then clears it.",
        evidence: "Why a flash survives exactly one redirect."
      },
      "ActionDispatch::ContentSecurityPolicy::Middleware" => {
        does: "Builds the CSP header and the per-request nonce.",
        evidence: "Content-Security-Policy response header."
      },
      "Rack::Head" => {
        does: "Runs a HEAD request as a GET, then discards the body.",
        evidence: "A HEAD gets the real headers without the payload."
      },
      "Rack::ConditionalGet" => {
        does: "Answers 304 when the client's validators still match.",
        evidence: "304 Not Modified, with no body sent."
      },
      "Rack::ETag" => {
        does: "Digests the body into an ETag so the next request can revalidate.",
        evidence: "ETag response header."
      },
      "Rack::TempfileReaper" => {
        does: "Deletes the tempfiles an upload created.",
        evidence: "Nothing left in tmp/ after a file upload."
      },
      "Rack::Attack" => {
        does: "Rate limits and blocks abusive requests before the app sees them.",
        evidence: "429 with a Retry-After header."
      }
    }.freeze

    Entry = Struct.new(:name, :does, :evidence, :documented, keyword_init: true) do
      def documented?
        documented
      end
    end

    class << self
      def entries
        names.map do |name|
          note = NOTES[name]
          Entry.new(
            name: name,
            does: note ? note[:does] : "Not yet annotated in this lab.",
            evidence: note ? note[:evidence] : nil,
            documented: !note.nil?
          )
        end
      end

      def names
        Rails.application.middleware.map(&:name)
      end

      def count
        names.size
      end

      # Any middleware in the real stack this lab has not described yet. Used
      # by a spec so the annotations cannot silently fall behind an upgrade.
      def undocumented
        names.uniq - NOTES.keys
      end

      # A duplicate registration is a real bug and worth surfacing rather than
      # quietly de-duplicating: it makes every throttle count twice.
      def duplicates
        names.tally.select { |_name, count| count > 1 }.keys
      end
    end
  end
end
