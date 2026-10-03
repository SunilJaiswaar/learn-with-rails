# A node in the interconnected skill tree (spec 50).
class Skill < ApplicationRecord
  include Sluggable

  belongs_to :world, optional: true
  belongs_to :technology, optional: true

  has_many :topics, dependent: :nullify
  has_many :challenges, dependent: :nullify
  has_many :questions, dependent: :nullify
  has_many :algorithms, dependent: :nullify
  has_many :skill_progresses, dependent: :destroy
  has_many :boss_battles, dependent: :nullify

  # Outgoing edges: skills this one requires.
  has_many :skill_dependencies, dependent: :destroy
  has_many :prerequisites, through: :skill_dependencies, source: :prerequisite

  # Incoming edges: skills that require this one.
  has_many :dependent_links, class_name: "SkillDependency",
                             foreign_key: :prerequisite_id, dependent: :destroy
  has_many :unlocks, through: :dependent_links, source: :skill

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :tier, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:tier, :position, :name) }
  scope :in_world, ->(world) { where(world: world) }

  def progress_for(user)
    return nil unless user

    skill_progresses.find_by(user_id: user.id)
  end
end
