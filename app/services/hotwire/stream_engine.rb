module Hotwire
  # Applies a Turbo Stream action to a modelled DOM list.
  #
  # The point of modelling it rather than describing it in prose is that the
  # lab's correct answers are *derived* by running the real operation, never
  # written by hand. A scenario cannot drift from what Turbo actually does,
  # because nothing states what Turbo does twice.
  class StreamEngine
    # The seven actions a <turbo-stream> element can carry.
    ACTIONS = %w[append prepend replace update remove before after].freeze

    # Actions that address the container; the rest address one element inside it.
    CONTAINER_ACTIONS = %w[append prepend].freeze

    CONTAINER_ID = "messages".freeze

    Result = Struct.new(:items, :error, keyword_init: true) do
      def ok?
        error.nil?
      end
    end

    class << self
      def apply(items, action:, target:, content: nil)
        action = action.to_s
        return Result.new(items: items, error: "unknown action '#{action}'") unless ACTIONS.include?(action)

        items = deep_copy(items)

        if CONTAINER_ACTIONS.include?(action)
          return container_miss(items, target) unless target == CONTAINER_ID

          return Result.new(items: send(action, items, content))
        end

        index = items.index { |item| item["id"] == target }
        # Turbo is silent about a target that is not on the page: the stream
        # arrives, matches nothing, and the DOM is unchanged. That silence is
        # the single most common reason a stream "does not work".
        return Result.new(items: items, error: "no element with id '#{target}'") if index.nil?

        Result.new(items: send(action, items, index, content))
      end

      private

      def append(items, content)
        items + [ content ]
      end

      def prepend(items, content)
        [ content ] + items
      end

      # replace swaps the element itself, so the new element's id replaces the
      # old one.
      def replace(items, index, content)
        items[0...index] + [ content ] + items[(index + 1)..]
      end

      # update swaps only the element's *contents*, so the element — and its
      # id — survives. This is the distinction that catches everyone.
      def update(items, index, content)
        items[index] = items[index].merge("text" => content["text"])
        items
      end

      def remove(items, index, _content)
        items[0...index] + items[(index + 1)..]
      end

      def before(items, index, content)
        items[0...index] + [ content ] + items[index..]
      end

      def after(items, index, content)
        items[0..index] + [ content ] + items[(index + 1)..]
      end

      def container_miss(items, target)
        Result.new(items: items, error: "no container with id '#{target}'")
      end

      def deep_copy(items)
        items.map { |item| item.dup }
      end
    end
  end
end
