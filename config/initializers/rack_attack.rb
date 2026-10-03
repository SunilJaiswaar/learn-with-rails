# Rate limiting (spec 73). Code execution and authentication are the two
# endpoints worth protecting hardest: one is expensive, the other is a target
# for credential stuffing.
class Rack::Attack
  # Health checks and assets must never be throttled.
  safelist("allow health checks and assets") do |request|
    request.path == "/up" || request.path.start_with?("/assets")
  end

  throttle("requests by ip", limit: 300, period: 5.minutes) do |request|
    request.ip unless request.path.start_with?("/assets")
  end

  # Sandbox runs cost real CPU, so they are limited per IP as well as per user
  # (the per-user limit lives in ChallengeAttemptsController).
  throttle("code execution by ip", limit: 30, period: 1.minute) do |request|
    request.ip if request.post? && request.path.match?(%r{\A/challenges/[^/]+/attempts})
  end

  throttle("logins by ip", limit: 10, period: 20.seconds) do |request|
    request.ip if request.path == "/login" && request.post?
  end

  # Throttling by email as well as IP blunts a distributed attack on one account.
  throttle("logins by email", limit: 10, period: 1.minute) do |request|
    if request.path == "/login" && request.post?
      request.params["email"].to_s.downcase.strip.presence
    end
  end

  throttle("signups by ip", limit: 5, period: 1.hour) do |request|
    request.ip if request.path == "/signup" && request.post?
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_i

    [ 429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      [ "Too many requests. Try again in #{retry_after} seconds.\n" ] ]
  end
end

# Rack::Attack needs its own cache store. A memory store is enough for a single
# process; a multi-process deployment should point this at Redis so counters are
# shared across workers.
Rack::Attack.cache.store =
  if Rails.env.production?
    ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
    )
  else
    ActiveSupport::Cache::MemoryStore.new
  end

# Throttling is off by default under test so that counters cannot leak between
# examples. The specs that assert throttling switch it on explicitly.
Rack::Attack.enabled = !Rails.env.test?
