class BossBattlesController < ApplicationController
  def index
    @boss_battles = BossBattle.published.includes(:skill, :world).order(:difficulty)
    @beaten_ids = current_user.boss_attempts.where(status: :won)
                              .pluck(:boss_battle_id).to_set
  end

  def show
    @boss_battle = BossBattle.published.includes(:skill, :world).find_by_slug!(params[:id])
    @attempt = current_user.boss_attempts
                           .where(boss_battle: @boss_battle)
                           .where(status: :in_progress)
                           .first
    @last_won = current_user.boss_attempts
                            .where(boss_battle: @boss_battle, status: :won).recent.first
  end

  def start
    @boss_battle = BossBattle.published.find_by_slug!(params[:id])
    attempt = current_user.boss_attempts
                          .where(boss_battle: @boss_battle, status: :in_progress).first
    attempt ||= current_user.boss_attempts.create!(
      boss_battle: @boss_battle, status: :in_progress, current_stage: 0
    )
    redirect_to boss_battle_path(@boss_battle.slug, stage: attempt.current_stage)
  end
end
