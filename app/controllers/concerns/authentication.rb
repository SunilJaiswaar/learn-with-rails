# Cookie-backed sessions with a server-side record, so a login can be revoked
# and a stolen cookie invalidated (spec 73).
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :codequest_session

  included do
    helper_method :current_user, :signed_in?
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = current_session&.user
  end

  def current_session
    return @current_session if defined?(@current_session)

    token = cookies.signed[SESSION_COOKIE]
    @current_session = Session.authenticate(token)
    @current_session&.touch_usage!
    @current_session
  end

  def signed_in?
    current_user.present?
  end

  def require_authentication
    return if signed_in?

    store_return_location
    redirect_to login_path, alert: "Please sign in to continue."
  end

  def sign_in(user)
    session_record = Session.start!(
      user: user,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    cookies.signed[SESSION_COOKIE] = {
      value: session_record.raw_token,
      expires: session_record.expires_at,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
    user.update_column(:last_seen_at, Time.current)
    @current_user = user
    @current_session = session_record
  end

  def sign_out
    current_session&.destroy
    cookies.delete(SESSION_COOKIE)
    @current_user = nil
    @current_session = nil
  end

  def store_return_location
    return unless request.get? && !request.xhr?

    session[:return_to] = request.fullpath
  end

  def stored_location_or(default)
    session.delete(:return_to) || default
  end
end
