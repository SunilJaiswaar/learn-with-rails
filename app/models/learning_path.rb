# A predefined route through the skill graph (spec 67).
class LearningPath < ApplicationRecord
  include Sluggable

  has_many :learning_path_steps, -> { order(:position) }, dependent: :destroy
  has_many :skills, through: :learning_path_steps

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :name) }
end
