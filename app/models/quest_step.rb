class QuestStep < ApplicationRecord
  belongs_to :quest
  belongs_to :target, polymorphic: true, optional: true

  validates :label, presence: true
  validates :position, uniqueness: { scope: :quest_id }

  scope :ordered, -> { order(:position) }

  def complete!(at = Time.current)
    return self if completed?

    update!(completed: true, completed_at: at)
    self
  end
end
