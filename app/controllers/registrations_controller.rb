class RegistrationsController < ApplicationController
  layout "public"

  allow_unauthenticated only: %i[new create]

  def new
    redirect_to dashboard_path and return if signed_in?

    @user = User.new
  end

  def create
    unless AppSetting["registration_open"]
      return redirect_to login_path, alert: "Registration is currently closed."
    end

    @user = User.new(user_params)
    @user.role = :learner      # never settable from the form

    if @user.save
      bootstrap_learner(@user)
      sign_in(@user)
      audit!("user.create", auditable: @user)
      redirect_to dashboard_path,
                  notice: "Welcome to #{product_name}. Your first mission is waiting."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: %i[name email password password_confirmation
                           experience_band timezone])
  end

  # A new learner should land on a dashboard that already has something to do.
  def bootstrap_learner(user)
    user.create_streak!(current_length: 0, longest_length: 0)
    Learning::QuestGenerator.new(user: user).call
  rescue StandardError => e
    # Onboarding extras must never block account creation.
    Rails.logger.warn("bootstrap_learner failed for user #{user.id}: #{e.class}: #{e.message}")
  end
end
