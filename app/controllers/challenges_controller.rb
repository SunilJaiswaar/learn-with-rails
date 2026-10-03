class ChallengesController < ApplicationController
  def index
    @challenges = Challenge.published
                           .includes(:skill, :topic)
                           .order(:difficulty, :title)
                           .page(params[:page]).per(20)
    @challenges = @challenges.where(challenge_type: params[:type]) if params[:type].present?
    @challenges = @challenges.where(skill_id: params[:skill_id]) if params[:skill_id].present?
    @solved_ids = current_user.challenge_attempts.successful.pluck(:challenge_id).to_set
    @skills = Skill.ordered
  end

  def show
    @challenge = Challenge.published
                          .includes(:skill, :topic, :challenge_tests)
                          .find_by_slug!(params[:id])
    @visible_tests = @challenge.challenge_tests.visible.ordered
    @ladder = Tutoring::HintLadder.new(user: current_user, challenge: @challenge)
    @revealed_hints = @ladder.revealed.ordered
    @attempts = current_user.challenge_attempts.where(challenge: @challenge).recent.limit(5)
    @best = @challenge.best_attempt_for(current_user)
    @code = params[:code].presence || @attempts.first&.submitted_code ||
            @challenge.starter_code
    @sandbox_available = CodeExecution::Runner.sandbox_available?
  end
end
