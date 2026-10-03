# Submits learner code for sandboxed evaluation.
class ChallengeAttemptsController < ApplicationController
  # Code execution is expensive and abusable, so it is rate limited per user
  # on top of the IP-level throttle in Rack::Attack.
  THROTTLE_WINDOW = 1.minute
  THROTTLE_LIMIT = 15

  def create
    @challenge = Challenge.published.includes(:challenge_tests).find_by_slug!(params[:challenge_id])

    if throttled?
      return respond_throttled
    end

    outcome = Challenges::Submission.new(
      user: current_user, challenge: @challenge, code: params[:code].to_s
    ).call

    @attempt = outcome.attempt
    @result = outcome.result
    @xp = outcome.xp
    @award = outcome.award
    @ladder = Tutoring::HintLadder.new(user: current_user, challenge: @challenge)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to challenge_path(@challenge.slug) }
    end
  end

  private

  def throttled?
    current_user.challenge_attempts
                .where(created_at: THROTTLE_WINDOW.ago..)
                .count >= THROTTLE_LIMIT
  end

  def respond_throttled
    message = "You are submitting very quickly. Wait a moment, then try again."
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "challenge-result",
          partial: "challenges/throttled", locals: { message: message }
        )
      end
      format.html { redirect_to challenge_path(@challenge.slug), alert: message }
    end
  end
end
