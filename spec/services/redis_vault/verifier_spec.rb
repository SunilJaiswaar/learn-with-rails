require "rails_helper"

RSpec.describe RedisVault::Verifier do
  # Each challenge is driven through the real engine, so these specs prove the
  # challenge is solvable by typing Redis commands — not merely that the
  # verifier agrees with a hand-built hash.
  def solve(*commands, limiter: nil)
    store = {}
    events = []
    commands.each { |c| RedisVault::Engine.new(store: store, events: events).call(c) }
    described_class.new(store: store, events: events, limiter: limiter || {})
  end

  def report_for(slug, verifier)
    verifier.call(RedisVault::Challenges.find(slug))
  end

  describe "expiring-session" do
    it "passes once the key exists and an expiry was set explicitly" do
      verifier = solve("SET session:checkout cart-9001", "EXPIRE session:checkout 600")
      expect(report_for("expiring-session", verifier)).to be_passed
    end

    it "fails on SET alone, because SET does not expire anything" do
      report = report_for("expiring-session", solve("SET session:checkout cart-9001"))
      expect(report).not_to be_passed
      expect(report.statuses.map(&:met)).to eq([ true, false, false ])
    end
  end

  describe "atomic-counter" do
    it "passes when the counter was incremented to 3" do
      verifier = solve("INCR page:views:home", "INCR page:views:home", "INCR page:views:home")
      expect(report_for("atomic-counter", verifier)).to be_passed
    end

    it "fails when the value was assigned rather than incremented" do
      report = report_for("atomic-counter", solve("SET page:views:home 3"))
      expect(report).not_to be_passed
      expect(report.statuses.map(&:met)).to eq([ true, false ])
    end

    it "fails when the count stops short" do
      report = report_for("atomic-counter", solve("INCR page:views:home"))
      expect(report).not_to be_passed
    end
  end

  describe "weekly-leaderboard" do
    it "passes with three players led by user:ace on 9000" do
      verifier = solve(
        "ZADD leaderboard:weekly 9000 user:ace",
        "ZADD leaderboard:weekly 4200 user:bo",
        "ZADD leaderboard:weekly 1500 user:cy"
      )
      expect(report_for("weekly-leaderboard", verifier)).to be_passed
    end

    it "fails when someone outranks user:ace" do
      verifier = solve(
        "ZADD leaderboard:weekly 9000 user:ace",
        "ZADD leaderboard:weekly 9900 user:bo",
        "ZADD leaderboard:weekly 1500 user:cy"
      )
      expect(report_for("weekly-leaderboard", verifier)).not_to be_passed
    end

    it "fails when the board is too small" do
      verifier = solve("ZADD leaderboard:weekly 9000 user:ace")
      report = report_for("weekly-leaderboard", verifier)
      expect(report.statuses.map(&:met)).to eq([ true, false, true ])
    end

    it "fails when the key is the wrong type" do
      expect(report_for("weekly-leaderboard", solve("SET leaderboard:weekly 9000"))).not_to be_passed
    end
  end

  describe "wrongtype-recovery" do
    it "passes after reproducing the error and rebuilding the key as a hash" do
      verifier = solve(
        "SET cart:9001 legacy-string",
        "HSET cart:9001 sku RB-204",
        "DEL cart:9001",
        "HSET cart:9001 sku RB-204"
      )
      expect(report_for("wrongtype-recovery", verifier)).to be_passed
    end

    it "fails when the hash was built without ever hitting the error" do
      report = report_for("wrongtype-recovery", solve("HSET cart:9001 sku RB-204"))
      expect(report.statuses.map(&:met)).to eq([ false, true, true ])
    end

    it "fails on the wrong field value" do
      verifier = solve("SET cart:9001 x", "HSET cart:9001 sku RB-204",
                       "DEL cart:9001", "HSET cart:9001 sku WRONG")
      expect(report_for("wrongtype-recovery", verifier)).not_to be_passed
    end
  end

  describe "exhaust-the-bucket" do
    it "passes once the bucket is empty and something was rejected" do
      verifier = solve(limiter: { "tokens" => 0, "blocked" => 5 })
      expect(report_for("exhaust-the-bucket", verifier)).to be_passed
    end

    it "fails while tokens remain" do
      verifier = solve(limiter: { "tokens" => 3, "blocked" => 0 })
      expect(report_for("exhaust-the-bucket", verifier)).not_to be_passed
    end

    it "fails on an empty bucket that never rejected anything" do
      verifier = solve(limiter: { "tokens" => 0, "blocked" => 0 })
      expect(report_for("exhaust-the-bucket", verifier)).not_to be_passed
    end
  end

  it "reports every challenge as unsolved on a fresh, empty vault" do
    verifier = described_class.new(store: {}, events: [], limiter: { "tokens" => 10, "blocked" => 0 })
    RedisVault::Challenges.all.each do |challenge|
      expect(verifier.call(challenge)).not_to be_passed, "#{challenge[:slug]} passes with nothing done"
    end
  end

  it "fails closed on a check it does not understand" do
    verifier = described_class.new(store: { "k" => { "type" => "string" } }, events: [])
    report = verifier.call(
      { slug: "x", objectives: [ { label: "nonsense", check: { nonsense: true } } ] }
    )
    expect(report).not_to be_passed
  end

  it "fails closed on an unknown key predicate" do
    verifier = described_class.new(store: { "k" => { "type" => "string" } }, events: [])
    report = verifier.call(
      { slug: "x", objectives: [ { label: "nonsense", check: { key: "k", nonsense: true } } ] }
    )
    expect(report).not_to be_passed
  end
end
