# Standalone practice on a single interview question, with follow-up probing.
class QuestionsController < ApplicationController
  def show
    @question = Question.published.includes(:skill, :question_follow_ups).find(params[:id])
    @attempts = current_user.question_attempts.where(question: @question).recent.limit(3)
  end

  def answer
    @question = Question.published.includes(:question_follow_ups).find(params[:id])
    evaluation = Interviews::AnswerEvaluator.new(
      question: @question, answer: params[:body].to_s
    ).call

    @attempt = current_user.question_attempts.create!(
      question: @question,
      response: params[:body].to_s,
      correct: evaluation.correct,
      score: evaluation.score,
      evaluation: evaluation.to_payload,
      xp_awarded: 0
    )

    award_and_record(evaluation)
    @follow_ups = @question.question_follow_ups.roots.ordered
                           .select { |f| f.triggered_by?(params[:body].to_s) }
                           .first(2)
    @evaluation = evaluation

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to question_path(@question) }
    end
  end

  private

  def award_and_record(evaluation)
    if evaluation.correct
      award = Gamification::XpAward.new(
        user: current_user, amount: @question.xp_award,
        reason: "Interview question answered: #{@question.body.truncate(40)}",
        source: @attempt,
        idempotency_key: "question:#{@question.id}"
      ).call
      @attempt.update_column(:xp_awarded, award.awarded)
    end

    if @question.skill
      dimension = @question.question_type == "output_prediction" ? :prediction : :explanation
      Mastery::Recorder.new(
        user: current_user, skill: @question.skill, dimension: dimension,
        score: evaluation.score, correct: evaluation.correct
      ).call
    end

    Learning::SpacedRepetition.new(user: current_user)
                              .record!(reviewable: @question, correct: evaluation.correct,
                                       skill: @question.skill)
    Gamification::StreakTracker.new(user: current_user).record_activity!
  end
end
