require "rails_helper"

RSpec.describe "Rails Request Lab", type: :request do
  let(:user) { create(:user) }
  let!(:skill) { skill_at("rails-request-cycle", name: "The Request Cycle") }

  before { sign_in_as(user) }

  def solve(slug, stage)
    post rails_lab_solve_path, params: { slug: slug, stage: stage },
                               headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "renders the pipeline, the challenges and the real middleware stack" do
    get rails_lab_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Rails Request Lab")
    expect(response.body).to include("0/5 correct")
    expect(response.body).to include("Rack::Attack")
    expect(response.body).to include(RailsLab::MiddlewareStack.count.to_s)
  end

  it "traces a request the learner composes" do
    post rails_lab_trace_path,
         params: { verb: "GET", path: "/worlds/rails-citadel" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("rails-citadel")
    expect(response.body).to include("turbo-stream")
  end

  it "shows which layer a failure stopped at" do
    post rails_lab_trace_path,
         params: { condition: "throttled" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.body).to include("429")
    expect(response.body).to include("not reached")
  end

  describe "challenges" do
    it "awards XP and records understanding for a correct layer" do
      expect { solve("who-answers-an-unknown-path", "router") }
        .to change { SkillProgress.where(user: user, skill: skill).count }.from(0).to(1)

      expect(response.body).to include("Correct.")
      expect(response.body).to include("1/5 correct")
      expect(user.xp_transactions.find_by(idempotency_key: "lab:rails_lab:who-answers-an-unknown-path").amount)
        .to eq(140)
      expect(SkillProgress.find_by(user: user, skill: skill).understanding_score).to be_positive
    end

    it "awards nothing for the wrong layer and records the miss" do
      solve("who-answers-an-unknown-path", "controller")

      expect(response.body).to include("Not that layer.")
      expect(user.xp_transactions.where("idempotency_key LIKE 'lab:rails_lab:%'")).to be_empty

      progress = SkillProgress.find_by(user: user, skill: skill)
      expect(progress.attempts_count).to eq(1)
      expect(progress.correct_count).to be_zero
    end

    it "accepts none for the slow query, which stops nothing" do
      solve("nothing-answered", "none")
      expect(response.body).to include("Correct.")
    end

    it "rejects naming a layer for the slow query" do
      solve("nothing-answered", "database")
      expect(response.body).to include("Not that layer.")
    end

    it "pays out once however often it is answered again" do
      3.times { solve("who-answers-a-throttled-request", "middleware") }

      expect(user.xp_transactions.where(idempotency_key: "lab:rails_lab:who-answers-a-throttled-request").count)
        .to eq(1)
    end

    it "is answerable correctly for every challenge" do
      RailsLab::Challenges.all.each do |challenge|
        answer = RailsLab::Challenges.answer_for(challenge) || :none
        solve(challenge[:slug], answer)
        expect(response.body).to include("Correct."), "#{challenge[:slug]} was not answerable"
      end

      expect(response.body).to include("5/5 correct")
    end

    it "remembers solved challenges from the ledger, not the session" do
      solve("who-answers-a-missing-record", "model")

      reset!
      sign_in_as(user)
      get rails_lab_path

      expect(response.body).to include("1/5 correct")
    end

    it "ignores an unknown challenge" do
      solve("not-a-challenge", "router")
      expect(response).to redirect_to(rails_lab_path)
    end
  end

  it "requires authentication" do
    delete logout_path
    get rails_lab_path
    expect(response).to redirect_to(login_path)
  end
end
