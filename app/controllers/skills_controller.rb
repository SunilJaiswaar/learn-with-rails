class SkillsController < ApplicationController
  def show
    @skill = Skill.includes(:world, :technology, :prerequisites, :unlocks).find_by_slug!(params[:id])
    @progress = @skill.progress_for(current_user)
    @topics = @skill.topics.published.ordered.includes(:curriculum_module)
    @challenges = @skill.challenges.published.order(:difficulty)
    @algorithms = @skill.algorithms.ordered
    @boss_battles = @skill.boss_battles.published
    @questions_count = @skill.questions.published.count
    @labs = Labs::Catalogue.for_skill(@skill.slug)
    @completed_topic_ids = current_user.topic_completions.finished.pluck(:topic_id).to_set
    @solved_challenge_ids = current_user.challenge_attempts.successful
                                        .pluck(:challenge_id).to_set
  end
end
