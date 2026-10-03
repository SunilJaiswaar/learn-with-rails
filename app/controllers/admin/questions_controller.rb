module Admin
  class QuestionsController < BaseController
    before_action :set_question, only: %i[show edit update destroy]

    def index
      authorize Question, :index?
      @questions = Question.includes(:skill, :question_follow_ups)
                           .order(:experience_band).page(params[:page]).per(25)
      @questions = @questions.where(question_type: params[:type]) if params[:type].present?
    end

    def show
      authorize @question, :show?
      @follow_ups = @question.question_follow_ups.ordered
    end

    def new
      authorize Question, :create?
      @question = Question.new
    end

    def create
      authorize Question, :create?
      @question = Question.new(question_params)
      if @question.save
        audit!("admin.question.create", auditable: @question)
        redirect_to admin_question_path(@question), notice: "Question created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @question, :update?
    end

    def update
      authorize @question, :update?
      if @question.update(question_params)
        redirect_to admin_question_path(@question), notice: "Question updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @question, :destroy?
      @question.destroy!
      redirect_to admin_questions_path, notice: "Question deleted."
    end

    private

    def set_question
      @question = Question.find(params[:id])
    end

    def question_params
      params.expect(question: %i[body question_type model_answer explanation
                                 common_mistakes difficulty experience_band
                                 company_type interview_type skill_id topic_id
                                 xp_award published])
    end
  end
end
