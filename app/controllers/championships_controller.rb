class ChampionshipsController < ApplicationController
  before_action :require_authentication

  def index
    session[:interview_champ_round] ||= 1
    session[:interview_champ_scores] ||= {}
    session[:capstone_stage] ||= 1
  end

  def interview
    session[:interview_champ_round] ||= 1
    session[:interview_champ_scores] ||= {}

    @current_round_num = session[:interview_champ_round]
    @total_rounds = Championships::InterviewChampionship.all_rounds.size

    if @current_round_num > @total_rounds
      @completed = true
      @scores = session[:interview_champ_scores]
      calculate_scorecard
    else
      @round = Championships::InterviewChampionship.round(@current_round_num)
    end
  end

  def answer_round
    session[:interview_champ_round] ||= 1
    session[:interview_champ_scores] ||= {}

    current_round_num = session[:interview_champ_round]
    round = Championships::InterviewChampionship.round(current_round_num)

    if round
      chosen_idx = params[:option_index].to_i
      is_correct = round[:options][chosen_idx]&.dig(:correct) || false
      session[:interview_champ_scores][current_round_num.to_s] = {
        "round_name" => round[:name],
        "competency" => round[:competency],
        "correct" => is_correct
      }

      session[:interview_champ_round] += 1
    end

    if session[:interview_champ_round] > Championships::InterviewChampionship.all_rounds.size
      Gamification::XpAward.new(
        user: current_user,
        amount: 500,
        reason: "Completed 12-Round Master Technical Interview Championship",
        idempotency_key: "interview-champ-completed-#{current_user.id}"
      ).call

      flash[:notice] = "🎉 Championship Completed! Evaluated across all 12 engineering rounds (+500 XP)."
    end

    redirect_to interview_championship_path
  end

  def reset_interview
    session[:interview_champ_round] = 1
    session[:interview_champ_scores] = {}
    redirect_to interview_championship_path, notice: "12-Round Interview Championship reset."
  end

  def developer_capstone
    session[:capstone_stage] ||= 1
    @current_stage = session[:capstone_stage]
    @stages = capstone_stages
  end

  def submit_capstone_stage
    session[:capstone_stage] ||= 1
    stage_num = session[:capstone_stage]
    choice = params[:choice]

    stage_info = capstone_stages.find { |s| s[:stage] == stage_num }
    if stage_info && stage_info[:options].find { |o| o[:id] == choice }&.dig(:correct)
      session[:capstone_stage] += 1

      if session[:capstone_stage] > capstone_stages.size
        Gamification::XpAward.new(
          user: current_user,
          amount: 600,
          reason: "Completed Scalable E-Commerce Developer Championship Capstone",
          idempotency_key: "capstone-completed-#{current_user.id}"
        ).call

        flash[:notice] = "🏆 DEVELOPER CHAMPIONSHIP CONQUERED! Full-stack architecture defended against all production failures (+600 XP)."
      else
        flash[:notice] = "Stage #{stage_num} cleared! Architectural choice verified."
      end
    else
      flash[:alert] = "Architectural decision failed under load. Review requirements and try an alternate design."
    end

    redirect_to developer_capstone_path
  end

  def reset_capstone
    session[:capstone_stage] = 1
    redirect_to developer_capstone_path, notice: "Developer Capstone reset."
  end

  private

  def calculate_scorecard
    total = @scores.size
    correct_count = @scores.values.count { |s| s["correct"] }
    @accuracy = total.positive? ? ((correct_count.to_f / total) * 100).round : 0

    @strong_areas = []
    @weak_areas = []

    @scores.each do |_k, v|
      if v["correct"]
        @strong_areas << v["round_name"]
      else
        @weak_areas << v["round_name"]
      end
    end
  end

  def capstone_stages
    [
      {
        stage: 1,
        title: "Stage 1: High-Volume Database Schema & ERD",
        scenario: "You are designing the core e-commerce schema for 10M orders/month. How should line items and products be related to prevent price drift on past orders?",
        options: [
          { id: "store_historical_price", text: "Store unit_price_at_purchase directly on line_items table, decoupling from current product price", correct: true },
          { id: "dynamic_foreign_key", text: "Always query product.price dynamically in real-time on line_items", correct: false }
        ]
      },
      {
        stage: 2,
        title: "Stage 2: Flash Sale Concurrency & Inventory",
        scenario: "10,000 users click 'Buy Now' simultaneously on 100 available units of a flash-sale item. How do you prevent inventory overselling?",
        options: [
          { id: "pessimistic_lock_db", text: "Use SELECT ... FOR UPDATE (with_lock) with DB check constraint (stock >= 0) or Redis atomic DECR", correct: true },
          { id: "in_memory_ruby_lock", text: "Check product.stock > 0 in controller before calling update without locks", correct: false }
        ]
      },
      {
        stage: 3,
        title: "Stage 3: Async Payment Processing & Failure Defense",
        scenario: "The payment gateway is experiencing intermittent 503 timeouts. Traffic is 5,000 RPS. How do you protect order workers?",
        options: [
          { id: "circuit_breaker_queue", text: "Deploy Circuit Breaker + Dedicated Priority Queue with Exponential Jittered Backoff", correct: true },
          { id: "infinite_retries", text: "Keep retrying immediately in a tight while loop until success", correct: false }
        ]
      },
      {
        stage: 4,
        title: "Stage 4: Edge Caching & Hotwire Frontend",
        scenario: "Catalog browsing is generating 50,000 reads/sec. How should product listing and shopping cart interact?",
        options: [
          { id: "cdn_cache_turbo_frame", text: "Cache public catalog HTML at CDN edge; lazy-load private user cart via independent <turbo-frame src=\"/cart\">", correct: true },
          { id: "disable_cdn", text: "Disable CDN and render all pages dynamically on Rails primary server", correct: false }
        ]
      }
    ]
  end
end
