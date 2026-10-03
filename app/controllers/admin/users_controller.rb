module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[show update]

    def index
      authorize User, :index?
      @users = User.order(created_at: :desc).page(params[:page]).per(30)
      @users = @users.where("email ILIKE :q OR name ILIKE :q",
                            q: "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%") if params[:q].present?
    end

    def show
      authorize @user, :show?
      @progresses = @user.skill_progresses.includes(:skill).weak_first
      @recent_attempts = @user.challenge_attempts.includes(:challenge).recent.limit(10)
    end

    def update
      authorize @user, :change_role?
      if @user.update(role: params.require(:user)[:role])
        audit!("admin.user.role_change", auditable: @user,
               metadata: { "role" => @user.role })
        redirect_to admin_user_path(@user), notice: "Role updated."
      else
        redirect_to admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
