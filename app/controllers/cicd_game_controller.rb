# The CI/CD pipeline repair game (spec 35): the learner reads the build log,
# finds why the security gate failed, and applies the fix.
class CicdGameController < ApplicationController
  SESSION_KEY = :cicd_security_fix

  def show
    @pipeline = current_pipeline.to_view_model
  end

  def run_pipeline
    fix = params[:security_fix].presence || session[SESSION_KEY]
    pipeline = Cicd::Pipeline.for(fix)

    if pipeline.passing?
      # Only the flag is stored: the pipeline itself is derived from it, so the
      # session stays a few bytes instead of overflowing the cookie.
      session[SESSION_KEY] = Cicd::Pipeline::REQUIRED_FIX
      award_repair
      redirect_to cicd_game_path,
                  notice: "Pipeline passed! Security scan clean, image built and " \
                          "deployed (+#{XP_REWARD} XP)."
    else
      session.delete(SESSION_KEY)
      redirect_to cicd_game_path,
                  alert: "Pipeline FAILED at stage 5 (Brakeman security scan). " \
                         "Fix the vulnerability to enable deployment."
    end
  end

  def reset
    session.delete(SESSION_KEY)
    redirect_to cicd_game_path, notice: "Pipeline reset to its failed state."
  end

  private

  XP_REWARD = 200

  def current_pipeline
    Cicd::Pipeline.for(session[SESSION_KEY])
  end

  def award_repair
    Labs::Completion.new(
      user: current_user, lab_key: "cicd_game", xp: XP_REWARD,
      reason: "Repaired the broken production CI/CD pipeline",
      detail: "pipeline-repaired"
    ).call
  end
end
