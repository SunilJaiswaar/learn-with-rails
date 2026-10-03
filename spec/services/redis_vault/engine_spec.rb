require "rails_helper"

RSpec.describe RedisVault::Engine do
  subject(:engine) { described_class.new(store: store, events: events) }

  let(:store) { {} }
  let(:events) { [] }

  def run(*commands)
    commands.map { |command| described_class.new(store: store, events: events).call(command) }.last
  end

  describe "strings" do
    it "stores and reads a value" do
      expect(run("SET greeting hello").output).to eq("OK")
      expect(run("GET greeting").output).to eq("\"hello\"")
    end

    it "reads a missing key as nil" do
      expect(run("GET nothing").output).to eq("(nil)")
    end

    it "leaves a new key persistent, as real Redis does" do
      run("SET greeting hello")
      expect(store["greeting"]["ttl"]).to eq(-1)
      expect(run("TTL greeting").output).to eq("(integer) -1")
    end

    it "joins a multi-word value" do
      run("SET motto ship small changes")
      expect(run("GET motto").output).to eq("\"ship small changes\"")
    end
  end

  describe "INCR" do
    it "increments from absent through to a running total" do
      expect(run("INCR hits").output).to eq("(integer) 1")
      expect(run("INCR hits").output).to eq("(integer) 2")
    end

    it "refuses to increment a non-numeric string" do
      run("SET name ada")
      expect(run("INCR name").output).to include("not an integer")
      expect(store["name"]["value"]).to eq("ada")
    end
  end

  describe "EXPIRE and TTL" do
    it "sets an expiry on an existing key" do
      run("SET session abc")
      expect(run("EXPIRE session 600").output).to eq("(integer) 1")
      expect(store["session"]["ttl"]).to eq(600)
    end

    it "reports no key to expire" do
      expect(run("EXPIRE ghost 60").output).to eq("(integer) 0")
    end

    it "distinguishes a missing key from a persistent one" do
      expect(run("TTL ghost").output).to eq("(integer) -2")
    end
  end

  describe "type safety" do
    it "refuses a hash write to a string key and records the error" do
      run("SET cart x")
      expect(run("HSET cart sku RB-204").output).to include("WRONGTYPE")
      expect(events).to include("ERR:WRONGTYPE")
    end

    it "allows the write once the key is removed" do
      run("SET cart x")
      run("HSET cart sku RB-204")
      run("DEL cart")
      expect(run("HSET cart sku RB-204").output).to eq("(integer) 1")
      expect(store["cart"]["type"]).to eq("hash")
    end

    it "refuses a string read of a hash" do
      run("HSET cart sku RB-204")
      expect(run("GET cart").output).to include("WRONGTYPE")
    end

    it "reports a key's type" do
      run("LPUSH queue job")
      expect(run("TYPE queue").output).to eq("list")
      expect(run("TYPE ghost").output).to eq("none")
    end
  end

  describe "sorted sets" do
    it "keeps members ordered by descending score" do
      run("ZADD board 100 bronze", "ZADD board 300 gold", "ZADD board 200 silver")
      expect(store["board"]["value"].map { |i| i["member"] }).to eq(%w[gold silver bronze])
    end

    it "updates a member's score in place rather than duplicating it" do
      run("ZADD board 100 ace")
      expect(run("ZADD board 900 ace").output).to eq("(integer) 0")
      expect(store["board"]["value"].size).to eq(1)
      expect(store["board"]["value"].first["score"]).to eq(900.0)
    end
  end

  describe "sets and lists" do
    it "does not add a duplicate set member" do
      expect(run("SADD tags ruby").output).to eq("(integer) 1")
      expect(run("SADD tags ruby").output).to eq("(integer) 0")
      expect(store["tags"]["value"]).to eq([ "ruby" ])
    end

    it "pushes onto the head of a list" do
      run("LPUSH queue first", "LPUSH queue second")
      expect(store["queue"]["value"]).to eq([ "second", "first" ])
    end
  end

  describe "limits" do
    it "refuses a new key past maxmemory rather than growing the session cookie" do
      described_class::MAX_KEYS.times { |i| run("SET key#{i} v") }
      expect(run("SET one-too-many v").output).to eq(described_class::OOM)
      expect(store.size).to eq(described_class::MAX_KEYS)
    end

    it "still overwrites an existing key when full" do
      described_class::MAX_KEYS.times { |i| run("SET key#{i} v") }
      expect(run("SET key0 replaced").output).to eq("OK")
      expect(store["key0"]["value"]).to eq("replaced")
    end

    it "truncates an oversized value" do
      run("SET big #{'x' * 500}")
      expect(store["big"]["value"].bytesize).to eq(described_class::MAX_VALUE_BYTES)
    end

    it "refuses a write that would push the store past its byte budget" do
      long = "v" * described_class::MAX_VALUE_BYTES
      10.times { |i| run("SET verylongkeyname:number:#{i} #{long}") }

      expect(store.to_json.bytesize).to be <= described_class::MAX_STORE_BYTES
    end

    it "leaves the store untouched by a write it had to reject" do
      long = "v" * described_class::MAX_VALUE_BYTES
      10.times { |i| run("SET verylongkeyname:number:#{i} #{long}") }
      snapshot = store.deep_dup

      expect(run("SET another:very:long:key:name #{long}").output).to eq(described_class::OOM)
      expect(store).to eq(snapshot)
    end

    it "does not record an event for a rejected write" do
      long = "v" * described_class::MAX_VALUE_BYTES
      10.times { |i| run("SET verylongkeyname:number:#{i} #{long}") }

      run("SET rejected:key:with:a:long:name #{long}")
      expect(events).not_to include("SET:rejected:key:with:a:long:name")
    end

    it "caps the event log and de-duplicates it" do
      40.times { |i| run("SET k#{i} v") }
      expect(events.size).to be <= described_class::MAX_EVENTS
      expect(events.uniq.size).to eq(events.size)
    end
  end

  describe "malformed input" do
    it "rejects an unknown verb" do
      expect(run("FLUSHALL").output).to include("unknown command 'FLUSHALL'")
    end

    it "rejects an empty command" do
      expect(run("   ").output).to include("empty command")
    end

    it "rejects a write with no key" do
      expect(run("SET").output).to include("wrong number of arguments")
      expect(store).to be_empty
    end

    it "rejects a ZADD with no member" do
      expect(run("ZADD board 100").output).to include("wrong number of arguments")
    end
  end
end
