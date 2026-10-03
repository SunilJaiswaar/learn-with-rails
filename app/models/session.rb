# Database-backed sessions so that logins can be listed and revoked, and so a
# stolen cookie can be invalidated server-side.
class Session < ApplicationRecord
  DEFAULT_LIFETIME = 30.days

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(expires_at: Time.current..) }
  scope :expired, -> { where(expires_at: ...Time.current) }

  attr_reader :raw_token

  # Only the digest is stored; the raw token lives in the signed cookie.
  def self.start!(user:, ip_address: nil, user_agent: nil, lifetime: DEFAULT_LIFETIME)
    raw = SecureRandom.urlsafe_base64(32)
    session = create!(
      user: user,
      token_digest: digest(raw),
      ip_address: ip_address,
      user_agent: user_agent.to_s.first(255).presence,
      expires_at: lifetime.from_now,
      last_used_at: Time.current
    )
    session.instance_variable_set(:@raw_token, raw)
    session
  end

  def self.authenticate(raw_token)
    return nil if raw_token.blank?

    active.find_by(token_digest: digest(raw_token))
  end

  def self.digest(raw_token)
    OpenSSL::Digest::SHA256.hexdigest(raw_token)
  end

  def touch_usage!
    update_column(:last_used_at, Time.current)
  end
end
