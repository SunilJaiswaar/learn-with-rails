# The blueprint for a daily mission (spec 51), framed as a production alert.
class QuestTemplate < ApplicationRecord
  include Sluggable

  belongs_to :skill, optional: true

  has_many :quests, dependent: :destroy

  validates :name, presence: true
  validates :briefing, presence: true
  validates :xp_reward, numericality: { greater_than: 0 }
  validate :step_specs_present

  scope :active, -> { where(active: true) }

  def steps
    Array(step_specs)
  end

  private

  def step_specs_present
    errors.add(:step_specs, "must define at least one step") if steps.empty?
  end
end
