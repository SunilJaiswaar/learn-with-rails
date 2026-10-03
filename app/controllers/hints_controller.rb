class HintsController < ApplicationController
  def create
    @challenge = Challenge.published.find_by_slug!(params[:challenge_id])
    @ladder = Tutoring::HintLadder.new(user: current_user, challenge: @challenge)
    @hint = @ladder.reveal_next!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to challenge_path(@challenge.slug) }
    end
  end
end
