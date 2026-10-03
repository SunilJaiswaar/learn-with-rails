class HomeController < ApplicationController
  layout "public"

  allow_unauthenticated only: %i[index]

  def index
    redirect_to dashboard_path and return if signed_in?

    @world_count = World.published.count
    @topic_count = Topic.published.count
    @challenge_count = Challenge.published.count
  end
end
