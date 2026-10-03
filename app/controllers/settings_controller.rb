class SettingsController < ApplicationController
  def show
    @user = current_user
    @sessions = current_user.sessions.active.order(last_used_at: :desc)
  end

  def update
    @user = current_user
    if @user.update(settings_params)
      redirect_to settings_path, notice: "Preferences saved."
    else
      @sessions = current_user.sessions.active
      render :show, status: :unprocessable_entity
    end
  end

  private

  # Deliberately narrow: role, XP and level are never user-settable.
  def settings_params
    params.expect(user: %i[name theme reduced_motion experience_band timezone])
  end
end
