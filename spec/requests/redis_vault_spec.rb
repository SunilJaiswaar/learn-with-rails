require "rails_helper"

RSpec.describe "Redis Vault", type: :request do
  let(:user) { create(:user) }
  let!(:skill) { skill_at("redis-caching", name: "Redis & Caching") }

  before { sign_in_as(user) }

  def execute(command)
    post redis_vault_execute_path, params: { command: command },
                                   headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "renders the vault with its challenges unsolved" do
    get redis_vault_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Vault Challenges")
    expect(response.body).to include("0/5 solved")
    expect(response.body).to include("Expire a session before it leaks")
  end

  it "runs a command against the simulated engine" do
    execute("SET greeting hello")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("OK")

    execute("GET greeting")
    expect(response.body).to include("hello")
  end

  it "awards XP and records Redis mastery when a challenge is solved" do
    execute("SET session:checkout cart-9001")
    expect(response.body).to include("0/5 solved")

    expect { execute("EXPIRE session:checkout 600") }
      .to change { SkillProgress.where(user: user, skill: skill).count }.from(0).to(1)

    expect(response.body).to include("1/5 solved")
    expect(response.body).to include("Expire a session before it leaks")

    entry = user.xp_transactions.find_by(idempotency_key: "lab:redis_vault:expiring-session")
    expect(entry.amount).to eq(120)
    expect(SkillProgress.find_by(user: user, skill: skill).application_score).to be_positive
  end

  it "schedules the Redis skill for revision" do
    execute("SET session:checkout c")
    execute("EXPIRE session:checkout 600")

    expect(ReviewSchedule.find_by(user: user, reviewable: skill)).to be_present
  end

  it "pays out once however many times a challenge is re-solved" do
    execute("SET session:checkout c")
    execute("EXPIRE session:checkout 600")
    execute("EXPIRE session:checkout 900")
    execute("EXPIRE session:checkout 1200")

    expect(user.xp_transactions.where(idempotency_key: "lab:redis_vault:expiring-session").count)
      .to eq(1)
  end

  it "does not award a challenge that was shortcut" do
    execute("SET page:views:home 3")

    expect(response.body).to include("0/5 solved")
    expect(user.xp_transactions.where("idempotency_key LIKE 'lab:redis_vault:%'")).to be_empty
  end

  it "awards the counter challenge for three real increments" do
    execute("INCR page:views:home")
    execute("INCR page:views:home")
    execute("INCR page:views:home")

    expect(user.xp_transactions.find_by(idempotency_key: "lab:redis_vault:atomic-counter").amount)
      .to eq(140)
  end

  it "awards the rate limiter challenge once the bucket is drained" do
    post redis_vault_blast_path(count: 15),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.body).to include("rate-limited")
    expect(user.xp_transactions.find_by(idempotency_key: "lab:redis_vault:exhaust-the-bucket"))
      .to be_present
  end

  it "resets the vault and its progress markers" do
    execute("SET session:checkout c")
    execute("EXPIRE session:checkout 600")

    post redis_vault_reset_path
    follow_redirect!

    expect(response.body).to include("0/5 solved")
  end

  # The whole vault lives in the session cookie, which holds 4KB. A learner
  # filling the store to its ceiling must not break every later request.
  it "keeps the session cookie under the 4KB browser limit when the store is full" do
    RedisVault::Engine::MAX_KEYS.times { |i| execute("SET key#{i} #{'v' * 120}") }
    post redis_vault_blast_path(count: 20), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    cookie = response.headers["Set-Cookie"]
    cookie = cookie.first if cookie.is_a?(Array)
    expect(cookie.to_s.bytesize).to be < 4096

    get redis_vault_path
    expect(response).to have_http_status(:ok)
  end

  it "refuses to grow the store past maxmemory" do
    RedisVault::Engine::MAX_KEYS.times { |i| execute("SET key#{i} v") }
    execute("SET one-too-many v")

    expect(response.body).to include("OOM command not allowed")
  end

  it "requires authentication" do
    delete logout_path
    get redis_vault_path
    expect(response).to redirect_to(login_path)
  end
end
