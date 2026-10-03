class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :deny_access
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  helper_method :product_name, :theme_preference, :reduced_motion?

  before_action :set_current_attributes

  private

  def deny_access
    respond_to do |format|
      format.html { redirect_to dashboard_path, alert: "You are not allowed to do that." }
      format.json { render json: { error: "forbidden" }, status: :forbidden }
    end
  end

  # Every format must be handled, including turbo_stream: without the catch-all
  # a missing record in a turbo_stream action answers 406 Not Acceptable rather
  # than 404, which hides an authorisation outcome behind a content-negotiation
  # error.
  def render_not_found
    respond_to do |format|
      format.html { render "shared/not_found", status: :not_found }
      format.json { render json: { error: "not_found" }, status: :not_found }
      format.any { head :not_found }
    end
  end

  def product_name
    AppSetting.product_name
  end

  # Theme is a user preference, defaulting to dark (spec 70). "system" renders
  # no override so the OS preference wins.
  def theme_preference
    current_user&.theme.presence || "dark"
  end

  def reduced_motion?
    current_user&.prefers_reduced_motion? || false
  end

  def set_current_attributes
    Current.user = current_user
    Current.request_id = request.request_id
    Current.ip_address = request.remote_ip
  end

  def audit!(action, auditable: nil, metadata: {})
    AuditLog.record!(actor: current_user, action: action, auditable: auditable,
                     metadata: metadata, ip_address: request.remote_ip)
  end
end
