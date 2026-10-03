# The AI tutor (spec 55): explains why a submission failed, without revealing
# the solution. Backed by whichever Tutoring::Provider is configured.
class ExplanationsController < ApplicationController
  def create
    @attempt = current_user.challenge_attempts.find(params[:attempt_id])
    @challenge = @attempt.challenge
    @explanation = Tutoring::Provider.current.explain_attempt(@attempt)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to challenge_path(@challenge.slug) }
    end
  end
end
