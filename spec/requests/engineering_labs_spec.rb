require "rails_helper"

RSpec.describe "Engineering Laboratories & Interactive Simulators", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe "discovering a lab from its skill" do
    it "lists the skill's laboratories on the skill page" do
      skill = create(:skill, slug: "web-security", name: "Web Security")

      get skill_path(skill.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Security Fortress")
      expect(response.body).to include(security_lab_path)
    end

    it "says nothing about labs on a skill that has none" do
      skill = create(:skill, slug: "some-other-skill")

      get skill_path(skill.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Laboratories")
    end
  end

  describe "System Design Universe" do
    it "renders the challenge index" do
      get system_design_index_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("System Design Universe")
      expect(response.body).to include("URL Shortener")
    end

    it "renders an interactive challenge workbench" do
      get system_design_challenge_path("url-shortener")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Architectural Building Blocks")
      expect(response.body).to include("Traffic Load (RPS)")
    end

    it "simulates architecture under production traffic" do
      post system_design_simulate_path("url-shortener"),
           params: {
             components: %w[client dns cdn load_balancer app_servers postgresql_primary postgresql_replicas redis_cache],
             rps: 25000
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("simulation-results")
      expect(response.body).to include("OPTIMAL")
    end
  end

  describe "Networking Lab" do
    it "renders the multi-layer pipeline" do
      get network_lab_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Networking Lab &amp; Packet Inspector")
      expect(response.body).to include("Packet Inspector")
    end

    it "inspects a specific layer via turbo stream" do
      post network_lab_inspect_path,
           params: { layer: "tls" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("TLS 1.3 Handshake")
    end

    it "awards XP on solving a networking challenge" do
      expect {
        post network_lab_solve_path,
             params: { challenge_id: "https_security", answer: "encryption_authentication" }
      }.to change { user.reload.xp_total }.by(150)
    end
  end

  describe "Redis Vault" do
    it "renders the memory explorer" do
      get redis_vault_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Redis Vault &amp; Memory Simulator")
    end

    it "executes interactive commands" do
      post redis_vault_execute_path,
           params: { command: "SET counter:hits 42" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OK")
    end

    it "simulates token bucket rate limiting" do
      post redis_vault_blast_path,
           params: { count: 15 }

      expect(response).to redirect_to(redis_vault_path)
      follow_redirect!
      expect(response.body).to include("rate-limited (HTTP 429 Too Many Requests)")
    end
  end

  describe "Sidekiq Factory" do
    it "renders the queue and concurrency workbench" do
      get sidekiq_factory_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sidekiq Factory &amp; Job Simulator")
    end

    it "enqueues jobs" do
      post sidekiq_factory_enqueue_path,
           params: { queue: "critical", count: 10 }

      expect(response).to redirect_to(sidekiq_factory_path)
      follow_redirect!
      expect(response.body).to include("Enqueued 10 jobs")
    end

    it "resolves a retry storm incident and awards XP" do
      post sidekiq_factory_trigger_incident_path
      expect {
        post sidekiq_factory_resolve_incident_path,
             params: { solution: "weighted_queues_circuit_breaker" }
      }.to change { user.reload.xp_total }.by(250)
    end
  end

  describe "Git Time Machine" do
    it "renders the commit DAG" do
      get git_lab_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Git Time Machine &amp; DAG Visualizer")
    end

    it "executes git commands" do
      post git_lab_execute_path,
           params: { command: "git status" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("On branch main")
    end

    it "resolves a merge conflict and awards XP" do
      expect {
        post git_lab_resolve_conflict_path,
             params: { resolved_code: "class User < ApplicationRecord\n  has_secure_password\n  validates :email, presence: true\nend" }
      }.to change { user.reload.xp_total }.by(150)
    end
  end

  describe "CI/CD Pipeline Game" do
    it "renders the pipeline runner" do
      get cicd_game_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CI/CD Pipeline Game")
    end

    it "patches code and completes green deployment" do
      expect {
        post cicd_game_run_path,
             params: { security_fix: "parameterized_query" }
      }.to change { user.reload.xp_total }.by(200)

      follow_redirect!
      expect(response.body).to include("PASSED")
    end
  end

  describe "Security Fortress" do
    it "renders the vulnerability labs" do
      get security_lab_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Security Fortress")
    end

    it "simulates an exploit against vulnerable and secured code" do
      post security_lab_exploit_path,
           params: { lab: "sql_injection", payload: "' OR '1'='1' --", mode: "vulnerable" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("EXPLOIT SUCCESSFUL")

      expect {
        post security_lab_exploit_path,
             params: { lab: "sql_injection", payload: "' OR '1'='1' --", mode: "secured" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change { user.reload.xp_total }.by(150)

      expect(response.body).to include("BLOCKED")
    end
  end

  describe "CPU Scheduler Game" do
    it "renders the scheduler and Gantt chart" do
      get cpu_scheduler_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CPU Scheduler Game")
      expect(response.body).to include("Gantt Chart")
    end

    it "simulates SJF scheduling and awards XP" do
      expect {
        post cpu_scheduler_simulate_path,
             params: { algorithm: "sjf" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change { user.reload.xp_total }.by(150)
    end
  end

  describe "Production Incidents War Room" do
    it "lists active incidents" do
      get incidents_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Production Incidents &amp; Debugging World")
      expect(response.body).to include("N+1 Query Firestorm")
    end

    it "resolves an incident and awards XP" do
      expect {
        post resolve_incident_path("n-plus-one-firestorm"),
             params: { remediation_id: "eager_loading" }
      }.to change { user.reload.xp_total }.by(250)

      follow_redirect!
      expect(response.body).to include("Incident resolved!")
    end
  end

  describe "Championship Arena" do
    it "renders the arena hub" do
      get championships_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The Engineering Championships")
    end

    it "progresses through technical interview rounds" do
      get interview_championship_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Round 1 of 12")

      post answer_interview_championship_path,
           params: { option_index: 0 }

      expect(response).to redirect_to(interview_championship_path)
      follow_redirect!
      expect(response.body).to include("Round 2 of 12")
    end

    it "advances through developer capstone stages" do
      get developer_capstone_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Stage 1 of 4")

      post submit_capstone_stage_path,
           params: { choice: "store_historical_price" }

      expect(response).to redirect_to(developer_capstone_path)
      follow_redirect!
      expect(response.body).to include("Stage 2 of 4")
    end
  end
end
