class SidekiqFactoryController < ApplicationController
  before_action :require_authentication

  def show
    session[:sidekiq_state] ||= default_state
    @state = session[:sidekiq_state]
  end

  def enqueue_job
    session[:sidekiq_state] ||= default_state
    queue = params[:queue].presence || "default"
    count = params[:count].to_i.clamp(1, 1000)

    session[:sidekiq_state]["queues"][queue] ||= 0
    session[:sidekiq_state]["queues"][queue] += count
    session[:sidekiq_state]["processed"] += count

    flash[:notice] = "Enqueued #{count} jobs into '#{queue}' queue."
    redirect_to sidekiq_factory_path
  end

  def trigger_incident
    session[:sidekiq_state] ||= default_state
    session[:sidekiq_state]["queues"]["mailers"] = 8400
    session[:sidekiq_state]["queues"]["default"] = 2100
    session[:sidekiq_state]["retries"] = 4850
    session[:sidekiq_state]["dead"] = 420
    session[:sidekiq_state]["error_message"] = "Net::OpenTimeout: execution expired (3rd-party SMS Gateway 503)"
    session[:sidekiq_state]["incident_active"] = true

    flash[:alert] = "🚨 INCIDENT TRIGGERED: 10,000+ jobs stuck in retry storm! Workers saturated retrying dead SMS deliveries."
    redirect_to sidekiq_factory_path
  end

  def resolve_incident
    session[:sidekiq_state] ||= default_state
    solution = params[:solution]

    if solution == "weighted_queues_circuit_breaker"
      session[:sidekiq_state]["queues"]["mailers"] = 0
      session[:sidekiq_state]["queues"]["default"] = 0
      session[:sidekiq_state]["retries"] = 0
      session[:sidekiq_state]["dead"] = 0
      session[:sidekiq_state]["incident_active"] = false
      session[:sidekiq_state]["error_message"] = nil

      Labs::Completion.new(
        user: current_user, lab_key: "sidekiq_factory", xp: 250,
        reason: "Resolved Sidekiq Retry Storm & Queue Starvation Incident",
        detail: "retry-storm"
      ).call

      flash[:notice] = "🏆 Excellent diagnosis! You prioritized queues (-q critical,5 -q default,2 -q mailers,1) and applied a Circuit Breaker on the failing gateway (+250 XP)."
    else
      flash[:alert] = "Diagnosis incorrect. Restarting workers alone without queue prioritization or circuit breakers will just restart the retry storm!"
    end

    redirect_to sidekiq_factory_path
  end

  def reset
    session[:sidekiq_state] = default_state
    redirect_to sidekiq_factory_path, notice: "Sidekiq Factory reset to healthy state."
  end

  private

  def default_state
    {
      "queues" => {
        "critical" => 4,
        "default" => 18,
        "mailers" => 65
      },
      "workers" => [
        { "id" => 1, "status" => "busy", "job" => "ProcessOrderPaymentJob", "queue" => "critical", "started_at" => "2s ago" },
        { "id" => 2, "status" => "busy", "job" => "SendWelcomeEmailJob", "queue" => "mailers", "started_at" => "1s ago" },
        { "id" => 3, "status" => "busy", "job" => "GenerateMonthlyInvoiceJob", "queue" => "default", "started_at" => "4s ago" },
        { "id" => 4, "status" => "idle", "job" => nil, "queue" => nil, "started_at" => nil },
        { "id" => 5, "status" => "idle", "job" => nil, "queue" => nil, "started_at" => nil }
      ],
      "retries" => 2,
      "dead" => 0,
      "processed" => 14820,
      "incident_active" => false,
      "error_message" => nil
    }
  end
end
