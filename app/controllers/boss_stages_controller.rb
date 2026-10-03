# Boss battles are multi-stage and mix disciplines, so one memorised trick is
# not enough to win (spec 52).
class BossStagesController < ApplicationController
  def update
    @boss_battle = BossBattle.published.find_by_slug!(params[:boss_battle_id])
    @attempt = current_user.boss_attempts
                           .where(boss_battle: @boss_battle, status: :in_progress)
                           .first

    return redirect_to boss_battle_path(@boss_battle.slug), alert: "Start the battle first." if @attempt.nil?

    outcome = BossBattles::StageEvaluator.new(
      attempt: @attempt, answer: params[:answer].to_s
    ).call

    @outcome = outcome
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to boss_battle_path(@boss_battle.slug) }
    end
  end
end
