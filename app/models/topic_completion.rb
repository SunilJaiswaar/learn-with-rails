class TopicCompletion < ApplicationRecord
  belongs_to :user
  belongs_to :topic

  validates :topic_id, uniqueness: { scope: :user_id }

  scope :finished, -> { where.not(completed_at: nil) }

  def finished?
    completed_at.present?
  end
end
