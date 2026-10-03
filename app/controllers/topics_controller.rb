# The lesson player. A topic is a sequence of typed interactive blocks, never a
# wall of prose (spec 4).
class TopicsController < ApplicationController
  before_action :set_topic, only: %i[show complete]

  def show
    @blocks = @topic.lesson_blocks.includes(:lesson).order("lessons.position, lesson_blocks.position")
    @completion = @topic.completion_for(current_user)
    @challenges = @topic.challenges.published.order(:difficulty)
    @questions = @topic.questions.published.includes(:question_follow_ups).limit(3)
    @solved_challenge_ids = current_user.challenge_attempts.successful
                                        .pluck(:challenge_id).to_set
    @next_topic = next_topic_in_module
  end

  def complete
    completion = Learning::TopicProgress.new(user: current_user, topic: @topic).complete!
    redirect_to topic_path(@topic.slug),
                notice: completion.finished? ? "Mission complete. +#{@topic.xp_award} XP" : nil
  end

  private

  def set_topic
    @topic = Topic.published
                  .includes(:skill, :curriculum_module, :technology_version)
                  .find_by_slug!(params[:id])
  end

  def next_topic_in_module
    @topic.curriculum_module.topics.published
          .where("position > ?", @topic.position)
          .ordered.first
  end
end
