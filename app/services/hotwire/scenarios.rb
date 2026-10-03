module Hotwire
  # Prediction challenges for Turbo Streams.
  #
  # Every scenario states only the *inputs* — a starting list, an action, a
  # target, a template. The correct answer is produced by running
  # StreamEngine, and the wrong answers are produced by running the actions
  # a learner plausibly confuses it with. Nothing here hand-writes an
  # expected DOM, so a scenario cannot disagree with the engine, and every
  # distractor is a real result rather than an invented one.
  module Scenarios
    START = [
      { "id" => "msg_1", "text" => "Deploy queued" },
      { "id" => "msg_2", "text" => "Running migrations" },
      { "id" => "msg_3", "text" => "Deploy finished" }
    ].freeze

    SCENARIOS = [
      {
        slug: "update-keeps-the-element",
        title: "update: what survives?",
        xp_reward: 130,
        action: "update",
        target: "msg_2",
        content: { "id" => "msg_99", "text" => "Migrations complete" },
        confusables: [ { action: "replace" } ],
        lesson: "update swaps an element's *contents* and leaves the element " \
                "— and its id — in place. The id in your template is ignored, " \
                "which is why msg_2 is still msg_2."
      },
      {
        slug: "replace-swaps-the-element",
        title: "replace: what survives?",
        xp_reward: 130,
        action: "replace",
        target: "msg_2",
        content: { "id" => "msg_99", "text" => "Migrations complete" },
        confusables: [ { action: "update" } ],
        lesson: "replace swaps the whole element, so your template's id is " \
                "the one that remains. Reach for update when something else " \
                "targets that id; reach for replace when the element itself " \
                "should change."
      },
      {
        slug: "before-is-relative-to-an-element",
        title: "before or prepend?",
        xp_reward: 140,
        action: "before",
        target: "msg_3",
        content: { "id" => "msg_50", "text" => "Warming caches" },
        confusables: [ { action: "prepend", target: StreamEngine::CONTAINER_ID }, { action: "after" } ],
        lesson: "before and after are positioned relative to an *element*. " \
                "append and prepend are positioned relative to the " \
                "*container*. Same insertion, different frame of reference."
      },
      {
        slug: "after-in-the-middle",
        title: "after, mid-list",
        xp_reward: 140,
        action: "after",
        target: "msg_1",
        content: { "id" => "msg_50", "text" => "Warming caches" },
        confusables: [ { action: "append", target: StreamEngine::CONTAINER_ID }, { action: "before" } ],
        lesson: "after inserts immediately below its target. On the *last* " \
                "element it happens to land in the same place as append — " \
                "which is why it is easy to believe they are the same thing."
      },
      {
        slug: "remove-ignores-its-template",
        title: "remove, with a template",
        xp_reward: 120,
        action: "remove",
        target: "msg_2",
        content: { "id" => "msg_99", "text" => "This template is ignored" },
        confusables: [ { action: "update" }, { action: "replace" } ],
        lesson: "remove needs only a target. Any template you send with it is " \
                "discarded, so a remove that appears to do nothing is almost " \
                "always a target that matched nothing."
      },
      {
        slug: "a-missing-target-is-silent",
        title: "the target is not on the page",
        xp_reward: 150,
        action: "replace",
        target: "msg_404",
        content: { "id" => "msg_99", "text" => "Rolled back" },
        confusables: [
          { action: "append", target: StreamEngine::CONTAINER_ID },
          { action: "replace", target: "msg_1" }
        ],
        lesson: "Turbo matches the target by id and does nothing when there " \
                "is no match — no error, no console warning, no fallback. A " \
                "stream that 'does not work' is usually arriving correctly " \
                "and matching nothing."
      }
    ].freeze

    Option = Struct.new(:digest, :items, keyword_init: true)

    class << self
      def all
        SCENARIOS
      end

      def find(slug)
        SCENARIOS.find { |scenario| scenario[:slug] == slug.to_s }
      end

      def slugs
        SCENARIOS.map { |scenario| scenario[:slug] }
      end

      # The DOM Turbo actually produces for this scenario.
      def correct_items(scenario)
        run(scenario, scenario[:action], scenario[:target])
      end

      def correct_digest(scenario)
        digest(correct_items(scenario))
      end

      # The correct answer plus the results of the actions it is confused
      # with, de-duplicated and ordered by a hash of the slug so the right
      # answer is not always in the same position.
      def options_for(scenario)
        candidates = [ correct_items(scenario) ]
        scenario[:confusables].each do |confusable|
          candidates << run(scenario, confusable[:action], confusable[:target] || scenario[:target])
        end

        candidates
          .uniq { |items| digest(items) }
          .map { |items| Option.new(digest: digest(items), items: items) }
          .sort_by { |option| Digest::SHA256.hexdigest("#{scenario[:slug]}:#{option.digest}") }
      end

      def correct?(scenario, chosen_digest)
        chosen_digest.present? && chosen_digest == correct_digest(scenario)
      end

      def digest(items)
        Digest::SHA256.hexdigest(items.to_json).first(12)
      end

      private

      def run(scenario, action, target)
        StreamEngine.apply(
          START.map(&:dup), action: action, target: target, content: scenario[:content]
        ).items
      end
    end
  end
end
