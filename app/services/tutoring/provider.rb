module Tutoring
  # Chooses how the tutor and interviewer reason.
  #
  # The rule-based provider is the default and has no external dependency: it
  # reads the sandbox's own evidence and the authored answer key. The Anthropic
  # provider is used only when a key is configured *and* the optional gem is
  # installed, so the platform works identically with no credentials and
  # degrades back to rules if a call fails.
  module Provider
    class << self
      def current
        @current ||= resolve
      end

      def reset!
        @current = nil
      end

      # Available only when both halves are present. Checked lazily because
      # `anthropic` is an optional dependency, deliberately not in the Gemfile.
      def model_backed_available?
        api_key.present? && gem_available?
      end

      def api_key
        ENV["ANTHROPIC_API_KEY"].presence
      end

      def model
        ENV.fetch("ANTHROPIC_MODEL", "claude-opus-5")
      end

      def describe
        model_backed_available? ? "model-backed (#{model})" : "rubric"
      end

      private

      def resolve
        return AnthropicProvider.new if model_backed_available?

        RuleBasedProvider.new
      end

      def gem_available?
        require "anthropic"
        true
      rescue LoadError
        false
      end
    end
  end
end
