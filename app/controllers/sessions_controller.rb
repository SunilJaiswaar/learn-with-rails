class SessionsController < ApplicationController
  layout "public"

  allow_unauthenticated only: %i[new create]

  # Brute-force protection is layered: Rack::Attack throttles by IP, and the
  # user record locks itself after repeated failures (spec 73).
  def new
    redirect_to dashboard_path and return if signed_in?

    @email = params[:email]
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.locked?
      return redirect_to login_path,
                         alert: "This account is temporarily locked. Try again shortly."
    end

    if user&.authenticate(params[:password])
      user.update_columns(failed_login_count: 0, locked_until: nil)
      sign_in(user)
      audit!("session.create", auditable: user)
      redirect_to stored_location_or(dashboard_path), notice: "Welcome back."
    else
      register_failure(user)
      # The same message for unknown email and wrong password, so the form does
      # not confirm which addresses exist.
      flash.now[:alert] = "That email and password combination is not valid."
      @email = params[:email]
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    audit!("session.destroy", auditable: current_user)
    sign_out
    redirect_to root_path, notice: "Signed out."
  end

  private

  def register_failure(user)
    return if user.nil?

    count = user.failed_login_count + 1
    attributes = { failed_login_count: count }
    if count >= User::MAX_FAILED_LOGINS
      attributes[:locked_until] = User::LOCKOUT_PERIOD.from_now
      attributes[:failed_login_count] = 0
    end
    user.update_columns(**attributes)
  end
end
