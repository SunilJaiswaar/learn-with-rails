require "rails_helper"

# The CI/CD repair game (spec 35). These specs exist because the page
# previously 500'd on every visit: the whole pipeline was being stored in the
# 4KB cookie session, which overflowed.
RSpec.describe "CI/CD pipeline game", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe "GET /cicd-game" do
    it "renders without overflowing the session cookie" do
      get cicd_game_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Brakeman")
    end

    it "keeps the session cookie well under the 4KB browser limit" do
      get cicd_game_path

      cookie = response.headers["Set-Cookie"].to_s
      expect(cookie.bytesize).to be < 4096
    end

    it "starts in the failed state with the security gate blocking deploy" do
      get cicd_game_path

      expect(response.body).to include("SQL Injection")
    end
  end

  describe "running the pipeline" do
    it "stays failed without the fix and awards nothing" do
      expect {
        post cicd_game_run_path, params: { security_fix: "add_a_comment" }
      }.not_to change { user.reload.xp_total }

      expect(flash[:alert]).to match(/FAILED at stage 5/)
    end

    it "passes with the parameterised-query fix and awards XP" do
      expect {
        post cicd_game_run_path, params: { security_fix: "parameterized_query" }
      }.to change { user.reload.xp_total }.by(200)

      expect(flash[:notice]).to match(/Pipeline passed/)
    end

    it "remembers the fix across requests" do
      post cicd_game_run_path, params: { security_fix: "parameterized_query" }
      get cicd_game_path

      expect(response.body).not_to include("CRITICAL WARNING")
    end

    it "awards the repair only once" do
      2.times do
        post cicd_game_run_path, params: { security_fix: "parameterized_query" }
      end

      expect(user.reload.xp_total).to eq(200)
    end

    it "resets back to the failed state" do
      post cicd_game_run_path, params: { security_fix: "parameterized_query" }
      post cicd_game_reset_path
      get cicd_game_path

      expect(response.body).to include("SQL Injection")
    end
  end

  describe Cicd::Pipeline do
    it "fails the security gate and skips everything after it" do
      pipeline = described_class.for(nil)
      statuses = pipeline.stages.map { |s| s["status"] }

      expect(pipeline).not_to be_passing
      expect(statuses).to eq(%w[passed passed passed passed failed skipped skipped])
    end

    it "passes every stage once the fix is applied" do
      pipeline = described_class.for("parameterized_query")

      expect(pipeline).to be_passing
      expect(pipeline.stages.map { |s| s["status"] }.uniq).to eq([ "passed" ])
    end

    it "does not treat an unrelated fix as sufficient" do
      expect(described_class.for("added_an_index")).not_to be_passing
    end

    it "shows the vulnerability in the failing log and not in the passing one" do
      expect(described_class.for(nil).logs).to include("SQL Injection")
      expect(described_class.for("parameterized_query").logs).not_to include("CRITICAL")
    end
  end
end
