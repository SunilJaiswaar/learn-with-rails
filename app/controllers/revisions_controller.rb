# The spaced-repetition queue (spec 47): whatever is due today, in one place.
class RevisionsController < ApplicationController
  def index
    repetition = Learning::SpacedRepetition.new(user: current_user)
    @due = repetition.due(limit: 20).includes(:skill)
    @upcoming = current_user.review_schedules.upcoming.soonest.limit(8).includes(:skill)
    @due_count = repetition.due_count
  end

  def show
    @schedule = current_user.review_schedules.find(params[:id])
    @reviewable = @schedule.reviewable
    redirect_to revision_target_path(@reviewable)
  end

  private

  def revision_target_path(reviewable)
    case reviewable
    when Challenge then challenge_path(reviewable.slug)
    when Topic then topic_path(reviewable.slug)
    when Question then question_path(reviewable)
    else revisions_path
    end
  end
end
