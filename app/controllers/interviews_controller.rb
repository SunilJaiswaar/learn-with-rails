class InterviewsController < ApplicationController
  def index
    @templates = InterviewTemplate.active.order(:experience_band, :name)
    @interviews = current_user.interviews.includes(:interview_template).recent.limit(10)
    @pressure_modes = Interview::PRESSURE_MODES.keys
    @company_types = Question::COMPANY_TYPES
  end

  def create
    template = InterviewTemplate.active.find(params[:interview_template_id])
    interview = Interviews::Builder.new(
      user: current_user,
      template: template,
      pressure_mode: permitted_mode,
      company_type: params[:company_type].presence
    ).call

    if interview.nil?
      redirect_to interviews_path,
                  alert: "There are not enough questions seeded for that track yet."
    else
      redirect_to interview_path(interview)
    end
  end

  def show
    @interview = current_user.interviews
                             .includes(interview_questions: %i[question question_follow_up
                                                               interview_answer])
                             .find(params[:id])
    @current = @interview.current_question

    if @current.nil? && @interview.in_progress_interview?
      Interviews::Session.new(interview: @interview).finish!
      @interview.reload
    end

    @answered = @interview.interview_questions.includes(:interview_answer, :question)
                          .select(&:answered?)
  end

  private

  # PRESSURE_MODES is keyed by symbol, so the incoming string param has to be
  # matched against the stringified names, not the keys directly.
  def permitted_mode
    mode = params[:pressure_mode].to_s
    Interview.pressure_modes.key?(mode) ? mode : "normal"
  end
end
