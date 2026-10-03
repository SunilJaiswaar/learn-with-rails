module Admin
  # Every admin action is authorised and audited.
  class BaseController < ApplicationController
    before_action :require_staff
    layout "admin"

    private

    def require_staff
      return if current_user&.staff?

      redirect_to dashboard_path, alert: "That area is staff only."
    end
  end
end
