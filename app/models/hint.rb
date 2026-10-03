# Progressive disclosure (spec 55): a nudge first, the solution last, and each
# reveal costs XP so hints stay a real choice.
class Hint < ApplicationRecord
  belongs_to :challenge

  LEVELS = {
    nudge: 0,
    concept: 1,
    clue: 2,
    pseudocode: 3,
    solution: 4,
    deep_explanation: 5
  }.freeze

  enum :level, LEVELS, suffix: :level, validate: true

  has_many :hint_reveals, dependent: :delete_all

  validates :body, presence: true
  validates :xp_penalty, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position) }

  def revealed_by?(user)
    return false unless user

    hint_reveals.where(user_id: user.id).exists?
  end
end
