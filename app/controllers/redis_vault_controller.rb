class RedisVaultController < ApplicationController
  before_action :require_authentication

  def show
    session[:redis_memory] ||= default_redis_store
    @redis_keys = session[:redis_memory]
    @rate_limiter = session[:rate_limiter] || { "tokens" => 5, "capacity" => 10, "blocked" => 0, "allowed" => 0 }
  end

  def execute_command
    session[:redis_memory] ||= default_redis_store
    cmd = params[:command].to_s.strip
    parts = cmd.split(/\s+/)
    verb = parts[0]&.upcase
    key = parts[1]
    val = parts[2..]&.join(" ")

    output = ""
    case verb
    when "SET"
      session[:redis_memory][key] = { "type" => "string", "value" => val, "ttl" => 300, "bytes" => val.bytesize + 32 }
      output = "OK"
    when "GET"
      entry = session[:redis_memory][key]
      output = entry ? "\"#{entry['value']}\"" : "(nil)"
    when "HSET"
      field = parts[2]
      fval = parts[3..]&.join(" ")
      entry = session[:redis_memory][key] ||= { "type" => "hash", "value" => {}, "ttl" => -1, "bytes" => 64 }
      if entry["type"] == "hash"
        entry["value"][field] = fval
        output = "(integer) 1"
      else
        output = "(error) WRONGTYPE Operation against a key holding the wrong kind of value"
      end
    when "HGETALL"
      entry = session[:redis_memory][key]
      if entry && entry["type"] == "hash"
        output = entry["value"].flat_map { |k, v| [ "\"#{k}\"", "\"#{v}\"" ] }.join("\n")
      else
        output = "(empty list or set)"
      end
    when "LPUSH"
      entry = session[:redis_memory][key] ||= { "type" => "list", "value" => [], "ttl" => -1, "bytes" => 48 }
      if entry["type"] == "list"
        entry["value"].unshift(val)
        output = "(integer) #{entry['value'].size}"
      else
        output = "(error) WRONGTYPE"
      end
    when "SADD"
      entry = session[:redis_memory][key] ||= { "type" => "set", "value" => [], "ttl" => -1, "bytes" => 56 }
      if entry["type"] == "set"
        entry["value"] << val unless entry["value"].include?(val)
        output = "(integer) 1"
      else
        output = "(error) WRONGTYPE"
      end
    when "ZADD"
      score = parts[2].to_f
      member = parts[3..]&.join(" ")
      entry = session[:redis_memory][key] ||= { "type" => "zset", "value" => [], "ttl" => -1, "bytes" => 64 }
      if entry["type"] == "zset"
        entry["value"].reject! { |item| item["member"] == member }
        entry["value"] << { "score" => score, "member" => member }
        entry["value"].sort_by! { |item| item["score"] }
        output = "(integer) 1"
      else
        output = "(error) WRONGTYPE"
      end
    when "INCR"
      entry = session[:redis_memory][key] ||= { "type" => "string", "value" => "0", "ttl" => -1, "bytes" => 40 }
      new_val = entry["value"].to_i + 1
      entry["value"] = new_val.to_s
      output = "(integer) #{new_val}"
    when "EXPIRE"
      seconds = parts[2].to_i
      if session[:redis_memory][key]
        session[:redis_memory][key]["ttl"] = seconds
        output = "(integer) 1"
      else
        output = "(integer) 0"
      end
    when "DEL"
      existed = session[:redis_memory].delete(key) ? 1 : 0
      output = "(integer) #{existed}"
    else
      output = "(error) ERR unknown command '#{verb}'"
    end

    @last_output = output
    @redis_keys = session[:redis_memory]
    @rate_limiter = session[:rate_limiter] || { "tokens" => 5, "capacity" => 10, "blocked" => 0, "allowed" => 0 }

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to redis_vault_path }
    end
  end

  def rate_limit_blast
    session[:rate_limiter] ||= { "tokens" => 5, "capacity" => 10, "blocked" => 0, "allowed" => 0 }
    limiter = session[:rate_limiter]

    count = params[:count].to_i.clamp(1, 20)
    allowed = 0
    blocked = 0

    count.times do
      if limiter["tokens"] > 0
        limiter["tokens"] -= 1
        limiter["allowed"] += 1
        allowed += 1
      else
        limiter["blocked"] += 1
        blocked += 1
      end
    end

    session[:rate_limiter] = limiter
    @redis_keys = session[:redis_memory] || default_redis_store
    @rate_limiter = limiter

    flash[:notice] = "Blasted #{count} requests: #{allowed} allowed (HTTP 200), #{blocked} rate-limited (HTTP 429 Too Many Requests)."

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to redis_vault_path }
    end
  end

  def reset_store
    session[:redis_memory] = default_redis_store
    session[:rate_limiter] = { "tokens" => 10, "capacity" => 10, "blocked" => 0, "allowed" => 0 }
    redirect_to redis_vault_path, notice: "Redis memory store reset to default."
  end

  private

  def default_redis_store
    {
      "user:session:9a7b" => { "type" => "string", "value" => "{\"user_id\":1402,\"role\":\"learner\"}", "ttl" => 3600, "bytes" => 128 },
      "orders:popular:count" => { "type" => "string", "value" => "4810", "ttl" => -1, "bytes" => 48 },
      "leaderboard:xp" => {
        "type" => "zset",
        "value" => [
          { "score" => 12450.0, "member" => "user:1402" },
          { "score" => 15800.0, "member" => "user:902" },
          { "score" => 21300.0, "member" => "user:101" }
        ],
        "ttl" => -1,
        "bytes" => 256
      },
      "active_tokens:ip:192.0.2.15" => { "type" => "string", "value" => "7", "ttl" => 45, "bytes" => 38 }
    }
  end
end
