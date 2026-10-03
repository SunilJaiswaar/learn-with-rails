# A multi-stage integrated challenge (spec 52). Stages deliberately mix
# disciplines, so a boss cannot be beaten by one memorised trick.
class BossBattle < ApplicationRecord
  include Sluggable
  include DifficultyScale

  slug_from :title

  belongs_to :skill, optional: true
  belongs_to :world, optional: true

  has_many :boss_attempts, dependent: :delete_all

  validates :title, presence: true
  validates :scenario, presence: true
  validates :boss_name, presence: true
  validate :stages_present

  scope :published, -> { where(published: true) }

  def stage_list
    Array(stages)
  end

  def stage_count
    stage_list.size
  end

  def beaten_by?(user)
    return false unless user

    boss_attempts.where(user_id: user.id, status: :won).exists?
  end

  private

  def stages_present
    errors.add(:stages, "must define at least one stage") if stage_list.empty?
  end
end
