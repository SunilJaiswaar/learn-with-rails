# Background jobs run on Sidekiq, backed by Redis.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

# Recurring jobs are registered on the server only, and only when a schedule
# file is present, so a one-off worker cannot start duplicating cron entries.
Sidekiq.configure_server do |config|
  schedule_file = Rails.root.join("config/schedule.yml")
  next unless schedule_file.exist?

  config.on(:startup) do
    require "sidekiq/cron"
    Sidekiq::Cron::Job.load_from_hash!(YAML.load_file(schedule_file))
  rescue LoadError, StandardError => e
    Rails.logger.warn("Could not load the recurring job schedule: #{e.class}: #{e.message}")
  end
end
