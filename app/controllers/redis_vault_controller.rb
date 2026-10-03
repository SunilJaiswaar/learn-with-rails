class RedisVaultController < ApplicationController
  before_action :require_authentication

  BUCKET_CAPACITY = 10

  def show
    load_state
  end

  def execute_command
    load_state

    result = RedisVault::Engine.new(store: @redis_keys, events: @events).call(params[:command])
    @last_output = result.output
    session[:redis_memory] = result.store
    session[:redis_events] = result.events
    @events = result.events

    notice = award_newly_completed
    build_reports

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice if notice }
      format.html { redirect_to redis_vault_path, notice: notice }
    end
  end

  def rate_limit_blast
    load_state

    count = params[:count].to_i.clamp(1, 20)
    allowed = 0
    blocked = 0

    count.times do
      if @rate_limiter["tokens"].to_i.positive?
        @rate_limiter["tokens"] -= 1
        @rate_limiter["allowed"] += 1
        allowed += 1
      else
        @rate_limiter["blocked"] += 1
        blocked += 1
      end
    end

    session[:rate_limiter] = @rate_limiter
    solved = award_newly_completed
    build_reports

    notice = "Blasted #{count} requests: #{allowed} allowed (HTTP 200), " \
             "#{blocked} rate-limited (HTTP 429 Too Many Requests)."
    notice = "#{solved} #{notice}" if solved

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice }
      format.html { redirect_to redis_vault_path, notice: notice }
    end
  end

  def reset_store
    session[:redis_memory] = default_redis_store
    session[:redis_events] = []
    session[:rate_limiter] = default_limiter
    redirect_to redis_vault_path, notice: "Redis memory store reset to default."
  end

  private

  def load_state
    session[:redis_memory] ||= default_redis_store
    session[:rate_limiter] ||= default_limiter

    @redis_keys = session[:redis_memory]
    @rate_limiter = session[:rate_limiter]
    @events = Array(session[:redis_events])
    build_reports
  end

  def build_reports
    verifier = RedisVault::Verifier.new(
      store: @redis_keys, events: @events, limiter: @rate_limiter
    )
    @reports = RedisVault::Challenges.all.map { |challenge| verifier.call(challenge) }
    @solved_count = @reports.count(&:passed)
  end

  # XP is keyed on the challenge slug inside Labs::Completion, so re-solving
  # a challenge is free practice: it records another attempt against the
  # Redis skill without paying out twice. Returns a notice for the newly
  # solved challenges only, so a solved board stays quiet.
  def award_newly_completed
    verifier = RedisVault::Verifier.new(
      store: @redis_keys, events: @events, limiter: @rate_limiter
    )

    solved = RedisVault::Challenges.all.filter_map do |challenge|
      next unless verifier.call(challenge).passed

      outcome = Labs::Completion.new(
        user: current_user, lab_key: "redis_vault",
        xp: challenge[:xp_reward],
        reason: "Redis Vault: #{challenge[:title]}",
        detail: challenge[:slug]
      ).call

      next unless outcome.xp.positive?

      "🧠 #{challenge[:title]} — solved! (+#{outcome.xp} XP)"
    end

    solved.presence&.join(" ")
  end

  def default_limiter
    { "tokens" => BUCKET_CAPACITY, "capacity" => BUCKET_CAPACITY, "blocked" => 0, "allowed" => 0 }
  end

  def default_redis_store
    {
      "user:session:9a7b" => {
        "type" => "string", "value" => "{\"user_id\":1402,\"role\":\"learner\"}",
        "ttl" => 3600, "bytes" => 128
      },
      "orders:popular:count" => {
        "type" => "string", "value" => "4810", "ttl" => -1, "bytes" => 48
      },
      "leaderboard:xp" => {
        "type" => "zset",
        "value" => [
          { "score" => 21300.0, "member" => "user:101" },
          { "score" => 15800.0, "member" => "user:902" },
          { "score" => 12450.0, "member" => "user:1402" }
        ],
        "ttl" => -1,
        "bytes" => 256
      },
      "active_tokens:ip:192.0.2.15" => {
        "type" => "string", "value" => "7", "ttl" => 45, "bytes" => 38
      }
    }
  end
end
