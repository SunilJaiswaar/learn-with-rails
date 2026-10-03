class BossAttempt < ApplicationRecord
  belongs_to :user
  belongs_to :boss_battle

  enum :status, { in_progress: 0, won: 1, lost: 2 }, suffix: :battle, validate: true

  scope :recent, -> { order(created_at: :desc) }

  def results
    Array(stage_results)
  end

  def stage_result_at(index)
    results.find { |r| r["stage"].to_i == index.to_i }
  end

  def current_stage_spec
    boss_battle.stage_list[current_stage]
  end

  def finished?
    won_battle? || lost_battle?
  end

  def progress_percent
    return 100 if finished?
    return 0 if boss_battle.stage_count.zero?

    ((current_stage.to_f / boss_battle.stage_count) * 100).round
  end
end
