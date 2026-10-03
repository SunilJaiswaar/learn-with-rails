module RedisVault
  # A deliberately small Redis simulator.
  #
  # It is extracted from the controller so the command semantics can be
  # tested directly, and so the limits below are enforced in one place. The
  # whole store lives in the session cookie, which holds 4KB: an unbounded
  # store is a 500 on every subsequent request, not a slow leak.
  class Engine
    MAX_KEYS = 24
    MAX_VALUE_BYTES = 128
    MAX_EVENTS = 30
    MAX_EVENT_LENGTH = 64

    # Both key names and values are learner-controlled, so a key count alone
    # does not bound the store: 24 keys with long names and values serialise
    # past the 4KB cookie. The budget is on the serialised bytes, and is set
    # well under 4096 to leave room for the auth session, the limiter, the
    # event log, and the ~1.4x encryption and base64 overhead on top.
    MAX_STORE_BYTES = 1800

    # Real Redis refuses writes once it is full rather than evicting silently
    # under the default policy, so the simulator says the same thing.
    OOM = "(error) OOM command not allowed when used memory > 'maxmemory'".freeze

    Result = Struct.new(:store, :output, :events, keyword_init: true)

    def initialize(store:, events: [])
      @store = store
      @events = Array(events)
    end

    def call(command)
      parts = command.to_s.strip.split(/\s+/)
      verb = parts[0]&.upcase
      key = parts[1]

      output =
        if verb.nil?
          "(error) ERR empty command"
        elsif WRITE_VERBS.include?(verb) && key.nil?
          "(error) ERR wrong number of arguments for '#{verb.downcase}' command"
        elsif WRITE_VERBS.include?(verb)
          within_budget { dispatch(verb, key, parts) }
        else
          dispatch(verb, key, parts)
        end

      Result.new(store: @store, output: output, events: @events)
    end

    WRITE_VERBS = %w[SET HSET LPUSH SADD ZADD INCR EXPIRE DEL].freeze

    private

    def dispatch(verb, key, parts)
      case verb
      when "SET"     then set(key, join(parts, 2))
      when "GET"     then get(key)
      when "HSET"    then hset(key, parts[2], join(parts, 3))
      when "HGETALL" then hgetall(key)
      when "LPUSH"   then lpush(key, join(parts, 2))
      when "SADD"    then sadd(key, join(parts, 2))
      when "ZADD"    then zadd(key, parts[2], join(parts, 3))
      when "INCR"    then incr(key)
      when "EXPIRE"  then expire(key, parts[2])
      when "TTL"     then ttl(key)
      when "TYPE"    then type_of(key)
      when "DEL"     then del(key)
      when "KEYS"    then keys
      else "(error) ERR unknown command '#{verb}'"
      end
    end

    # Applies a write, then rolls the whole store back if it no longer fits in
    # the cookie. Checking afterwards is exact, where estimating the cost of a
    # write in advance is not.
    def within_budget
      store_before = @store.deep_dup
      events_before = @events.dup

      output = yield
      return output if @store.to_json.bytesize <= MAX_STORE_BYTES

      @store.replace(store_before)
      @events.replace(events_before)
      OOM
    end

    def join(parts, from)
      Array(parts[from..]).join(" ").byteslice(0, MAX_VALUE_BYTES)
    end

    # Real Redis `SET` leaves a key persistent; an expiry is a separate
    # decision. The simulator used to attach a TTL silently, which taught the
    # opposite of the lesson that unexpiring cache entries leak.
    def set(key, value)
      return OOM if would_exceed_keys?(key)

      @store[key] = entry("string", value, bytes: value.bytesize + 32)
      record("SET", key)
      "OK"
    end

    def get(key)
      entry = @store[key]
      return "(nil)" if entry.nil?
      return wrongtype unless entry["type"] == "string"

      "\"#{entry['value']}\""
    end

    def hset(key, field, value)
      return "(error) ERR wrong number of arguments for 'hset' command" if field.nil?
      return OOM if would_exceed_keys?(key)

      entry = (@store[key] ||= entry("hash", {}, bytes: 64))
      return wrongtype unless entry["type"] == "hash"

      created = entry["value"].key?(field) ? 0 : 1
      entry["value"][field] = value
      record("HSET", key)
      "(integer) #{created}"
    end

    def hgetall(key)
      entry = @store[key]
      return "(empty list or set)" if entry.nil?
      return wrongtype unless entry["type"] == "hash"

      entry["value"].flat_map { |k, v| [ "\"#{k}\"", "\"#{v}\"" ] }.join("\n")
    end

    def lpush(key, value)
      return OOM if would_exceed_keys?(key)

      entry = (@store[key] ||= entry("list", [], bytes: 48))
      return wrongtype unless entry["type"] == "list"

      entry["value"].unshift(value)
      record("LPUSH", key)
      "(integer) #{entry['value'].size}"
    end

    def sadd(key, value)
      return OOM if would_exceed_keys?(key)

      entry = (@store[key] ||= entry("set", [], bytes: 56))
      return wrongtype unless entry["type"] == "set"

      added = entry["value"].include?(value) ? 0 : 1
      entry["value"] << value if added == 1
      record("SADD", key)
      "(integer) #{added}"
    end

    def zadd(key, score, member)
      return "(error) ERR wrong number of arguments for 'zadd' command" if score.nil? || member.empty?
      return OOM if would_exceed_keys?(key)

      entry = (@store[key] ||= entry("zset", [], bytes: 64))
      return wrongtype unless entry["type"] == "zset"

      existing = entry["value"].any? { |item| item["member"] == member }
      entry["value"].reject! { |item| item["member"] == member }
      entry["value"] << { "score" => score.to_f, "member" => member }
      entry["value"].sort_by! { |item| -item["score"] }
      record("ZADD", key)
      "(integer) #{existing ? 0 : 1}"
    end

    def incr(key)
      return OOM if would_exceed_keys?(key)

      entry = (@store[key] ||= entry("string", "0", bytes: 40))
      return wrongtype unless entry["type"] == "string"
      unless entry["value"].to_s.match?(/\A-?\d+\z/)
        return "(error) ERR value is not an integer or out of range"
      end

      entry["value"] = (entry["value"].to_i + 1).to_s
      record("INCR", key)
      "(integer) #{entry['value']}"
    end

    def expire(key, seconds)
      return "(integer) 0" if @store[key].nil?

      @store[key]["ttl"] = seconds.to_i
      record("EXPIRE", key)
      "(integer) 1"
    end

    def ttl(key)
      entry = @store[key]
      return "(integer) -2" if entry.nil?

      "(integer) #{entry['ttl']}"
    end

    def type_of(key)
      @store[key] ? @store[key]["type"] : "none"
    end

    def del(key)
      existed = @store.delete(key) ? 1 : 0
      record("DEL", key) if existed == 1
      "(integer) #{existed}"
    end

    def keys
      return "(empty list or set)" if @store.empty?

      @store.keys.map { |k| "\"#{k}\"" }.join("\n")
    end

    def entry(type, value, bytes:)
      { "type" => type, "value" => value, "ttl" => -1, "bytes" => bytes }
    end

    def would_exceed_keys?(key)
      !@store.key?(key) && @store.size >= MAX_KEYS
    end

    def wrongtype
      record_event("ERR:WRONGTYPE")
      "(error) WRONGTYPE Operation against a key holding the wrong kind of value"
    end

    def record(verb, key)
      record_event("#{verb}:#{key}")
    end

    # Events are how a challenge can require that the learner reached a state
    # the right way — three INCRs rather than one SET. Capped and de-duped
    # because they share the session cookie with the store.
    def record_event(token)
      token = token.byteslice(0, MAX_EVENT_LENGTH)
      return if @events.include?(token)

      @events << token
      @events.shift while @events.size > MAX_EVENTS
    end
  end
end
