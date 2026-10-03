# Shared 0-4 difficulty vocabulary so every piece of content speaks the same
# language to the adaptive engine.
module DifficultyScale
  extend ActiveSupport::Concern

  LEVELS = { intro: 0, easy: 1, medium: 2, hard: 3, expert: 4 }.freeze

  included do
    enum :difficulty, LEVELS, suffix: :difficulty, validate: true

    scope :at_most, ->(level) { where(difficulty: ..LEVELS.fetch(level.to_sym)) }
    scope :harder_than, ->(level) { where(difficulty: (LEVELS.fetch(level.to_sym) + 1)..) }
  end

  def difficulty_label
    difficulty.to_s.titleize
  end
end
