class InterviewAnswersController < ApplicationController
  def create
    @interview = current_user.interviews.find(params[:interview_id])
    interview_question = @interview.interview_questions.find(params[:interview_question_id])

    if interview_question.answered?
      return redirect_to interview_path(@interview), alert: "That question is already answered."
    end

    Interviews::Session.new(interview: @interview).submit_answer!(
      interview_question: interview_question,
      body: params[:body].to_s
    )

    redirect_to interview_path(@interview)
  end
end
