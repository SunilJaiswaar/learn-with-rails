# Branding and tunables, editable from the admin panel. Values are cached
# because they are read on nearly every request.
class AppSetting < ApplicationRecord
  CACHE_KEY = "app_settings/all"

  validates :key, presence: true, uniqueness: true

  after_commit :clear_cache

  DEFAULTS = {
    "product_name" => { "value" => "CodeQuest" },
    "tagline" => { "value" => "Learn by solving, not by reading." },
    "accent_color" => { "value" => "#6366f1" },
    "support_email" => { "value" => "support@example.com" },
    "registration_open" => { "value" => true }
  }.freeze

  def self.all_settings
    Rails.cache.fetch(CACHE_KEY, expires_in: 5.minutes) do
      DEFAULTS.merge(pluck(:key, :value).to_h)
    end
  rescue ActiveRecord::StatementInvalid
    DEFAULTS
  end

  def self.[](key)
    all_settings.dig(key.to_s, "value")
  end

  def self.set!(key, value)
    record = find_or_initialize_by(key: key.to_s)
    record.value = { "value" => value }
    record.save!
    record
  end

  def self.product_name
    self["product_name"].presence || "CodeQuest"
  end

  private

  def clear_cache
    Rails.cache.delete(CACHE_KEY)
  end
end
