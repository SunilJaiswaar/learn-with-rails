class LearningPathStep < ApplicationRecord
  belongs_to :learning_path
  belongs_to :skill

  validates :skill_id, uniqueness: { scope: :learning_path_id }

  scope :ordered, -> { order(:position) }
end
