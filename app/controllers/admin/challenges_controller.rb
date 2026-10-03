module Admin
  class ChallengesController < BaseController
    before_action :set_challenge, only: %i[show edit update destroy]

    def index
      authorize Challenge, :index?
      @challenges = Challenge.includes(:skill, :topic, :challenge_tests)
                             .order(:difficulty).page(params[:page]).per(25)
    end

    def show
      authorize @challenge, :show?
      @tests = @challenge.challenge_tests.ordered
      @hints = @challenge.hints.ordered
      @stats = {
        attempts: @challenge.challenge_attempts.count,
        passes: @challenge.challenge_attempts.successful.count
      }
    end

    def new
      authorize Challenge, :create?
      @challenge = Challenge.new(language: :ruby, challenge_type: :implement)
    end

    def create
      authorize Challenge, :create?
      @challenge = Challenge.new(challenge_params)
      if @challenge.save
        audit!("admin.challenge.create", auditable: @challenge)
        redirect_to admin_challenge_path(@challenge), notice: "Challenge created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @challenge, :update?
    end

    def update
      authorize @challenge, :update?
      if @challenge.update(challenge_params)
        audit!("admin.challenge.update", auditable: @challenge)
        redirect_to admin_challenge_path(@challenge), notice: "Challenge updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @challenge, :destroy?
      @challenge.destroy!
      redirect_to admin_challenges_path, notice: "Challenge deleted."
    end

    private

    def set_challenge
      @challenge = Challenge.find(params[:id])
    end

    def challenge_params
      params.expect(challenge: %i[title slug prompt starter_code reference_solution
                                  explanation challenge_type language difficulty
                                  skill_id topic_id xp_award time_limit_ms
                                  memory_limit_mb published])
    end
  end
end
