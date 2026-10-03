# Backing data for the step-through visualiser (spec 7). The frame sequence is
# computed in Ruby so the trace the learner steps through is the real algorithm,
# not a hand-drawn animation.
class Algorithm < ApplicationRecord
  include Sluggable

  belongs_to :skill, optional: true
  belongs_to :topic, optional: true

  has_many :algorithm_steps, -> { order(:position) }, dependent: :destroy

  VISUALIZER_KINDS = %w[array graph dp_table stack tree].freeze
  CATEGORIES = %w[
    searching sorting two_pointer sliding_window recursion
    graph dynamic_programming data_structure hashing greedy
  ].freeze

  validates :name, presence: true
  validates :visualizer_kind, inclusion: { in: VISUALIZER_KINDS }
  validates :category, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(:position, :name) }
  scope :in_category, ->(category) { where(category: category) }

  def default_input
    visualizer_config["input"] || [ 8, 3, 7, 4, 2, 9, 1 ]
  end

  def tradeoff_list
    Array(tradeoffs)
  end

  # Builds the frames for a given input using the matching tracer.
  def trace(input = nil)
    Algorithms::Tracer.for(self).call(input || default_input)
  end
end
