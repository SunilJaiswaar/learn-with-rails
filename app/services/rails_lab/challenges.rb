module RailsLab
  # "Which layer answered?" challenges.
  #
  # Knowing that Rails has middleware, a router and controllers is recall.
  # Knowing which of them turned a request into a 404 is the thing that makes
  # a production log readable, so that is what these ask. Every answer is
  # checked against Pipeline, so a challenge cannot disagree with the
  # simulator it is describing.
  module Challenges
    CHALLENGES = [
      {
        slug: "who-answers-an-unknown-path",
        title: "A path nobody routed",
        xp_reward: 140,
        condition: "unknown_path",
        prompt: "A request arrives for /skils/sql-joins — note the typo. The " \
                "response is 404. Which layer decided that?",
        lesson: "The router. It raises before any controller is chosen, which " \
                "is why you cannot rescue a bad path in a controller and why " \
                "`rescue_from RoutingError` in ApplicationController does " \
                "nothing."
      },
      {
        slug: "who-answers-a-throttled-request",
        title: "Refused before it arrived",
        xp_reward: 150,
        condition: "throttled",
        prompt: "A client sends 400 requests in a minute and starts getting " \
                "429 with a Retry-After header. Which layer refused them?",
        lesson: "Middleware. Rack::Attack sits in front of the router, so a " \
                "throttled request costs you almost nothing — no routing, no " \
                "controller, no database. That is the whole reason rate " \
                "limiting belongs in middleware rather than a before_action."
      },
      {
        slug: "who-answers-a-missing-record",
        title: "The record is gone",
        xp_reward: 140,
        condition: "record_not_found",
        prompt: "GET /skills/deleted-slug returns 404, but the route exists " \
                "and the controller ran. Which layer raised?",
        lesson: "The model. `find_by_slug!` raises ActiveRecord::RecordNotFound, " \
                "which ActionDispatch::ShowExceptions converts to a 404. The " \
                "controller started, the view never rendered."
      },
      {
        slug: "who-rejects-a-missing-csrf-token",
        title: "A POST with no token",
        xp_reward: 150,
        condition: "missing_csrf",
        prompt: "A POST without a CSRF token is rejected with 422. The session " \
                "cookie was read successfully first. Which layer rejected it?",
        lesson: "The controller. Cookies and session are decoded by middleware, " \
                "but forgery protection is a controller callback — so the " \
                "request is fully routed and the session loaded before it is " \
                "refused."
      },
      {
        slug: "nothing-answered",
        title: "The failure that does not announce itself",
        xp_reward: 160,
        condition: "slow_query",
        prompt: "A page takes 1.4 seconds. No error, no exception, status 200. " \
                "Which layer stopped the request?",
        lesson: "None of them — and that is the lesson. Every layer succeeded; " \
                "the only evidence is database time in the log line. Outages " \
                "announce themselves, slow queries do not, which is why you " \
                "watch percentiles rather than error rates."
      }
    ].freeze

    # The stage the learner must identify. Derived from Pipeline rather than
    # written down twice, so the challenge and the simulator cannot disagree.
    def self.answer_for(challenge)
      Pipeline::CONDITIONS.dig(challenge[:condition], :stops_at)
    end

    class << self
      def all
        CHALLENGES
      end

      def find(slug)
        CHALLENGES.find { |challenge| challenge[:slug] == slug.to_s }
      end

      def slugs
        CHALLENGES.map { |challenge| challenge[:slug] }
      end

      # "none" is a real answer for the slow-query case, so the options always
      # include it rather than forcing a wrong pick.
      def options
        Pipeline::STAGES + [ :none ]
      end

      def correct?(challenge, chosen)
        expected = answer_for(challenge) || :none
        chosen.to_s == expected.to_s
      end
    end
  end
end
