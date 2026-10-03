require "sidekiq/web"

Rails.application.routes.draw do
  root "home#index"

  # --- Authentication ----------------------------------------------------
  get    "login",  to: "sessions#new",     as: :login
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  get    "signup", to: "registrations#new",    as: :signup
  post   "signup", to: "registrations#create"

  # --- Learner experience ------------------------------------------------
  get "dashboard", to: "dashboard#show", as: :dashboard
  get "map",       to: "skill_map#show", as: :skill_map
  get "progress",  to: "progress#show",  as: :progress
  get "big-o",     to: "complexity#show", as: :complexity
  get "search",    to: "search#index",   as: :search

  # --- Engineering Laboratories & Simulators ----------------------------
  get  "system-design",            to: "system_design#index", as: :system_design_index
  get  "system-design/:slug",      to: "system_design#show",  as: :system_design_challenge
  post "system-design/:slug/simulate", to: "system_design#simulate", as: :system_design_simulate

  get  "network-lab",              to: "network_lab#show",         as: :network_lab
  post "network-lab/inspect",      to: "network_lab#inspect_layer", as: :network_lab_inspect
  post "network-lab/solve",        to: "network_lab#solve_challenge", as: :network_lab_solve

  get  "redis-vault",              to: "redis_vault#show",           as: :redis_vault
  post "redis-vault/execute",      to: "redis_vault#execute_command", as: :redis_vault_execute
  post "redis-vault/blast",        to: "redis_vault#rate_limit_blast", as: :redis_vault_blast
  post "redis-vault/reset",        to: "redis_vault#reset_store",    as: :redis_vault_reset

  get  "sidekiq-factory",          to: "sidekiq_factory#show",             as: :sidekiq_factory
  post "sidekiq-factory/enqueue",  to: "sidekiq_factory#enqueue_job",      as: :sidekiq_factory_enqueue
  post "sidekiq-factory/incident", to: "sidekiq_factory#trigger_incident", as: :sidekiq_factory_trigger_incident
  post "sidekiq-factory/resolve",  to: "sidekiq_factory#resolve_incident", as: :sidekiq_factory_resolve_incident
  post "sidekiq-factory/reset",    to: "sidekiq_factory#reset",            as: :sidekiq_factory_reset

  get  "git-lab",                  to: "git_lab#show",             as: :git_lab
  post "git-lab/execute",          to: "git_lab#execute_command",  as: :git_lab_execute
  post "git-lab/resolve-conflict", to: "git_lab#resolve_conflict", as: :git_lab_resolve_conflict
  post "git-lab/reset",            to: "git_lab#reset",            as: :git_lab_reset

  get  "cicd-game",                to: "cicd_game#show",         as: :cicd_game
  post "cicd-game/run",            to: "cicd_game#run_pipeline", as: :cicd_game_run
  post "cicd-game/reset",          to: "cicd_game#reset",        as: :cicd_game_reset

  get  "security-lab",             to: "security_lab#show",         as: :security_lab
  post "security-lab/exploit",     to: "security_lab#test_exploit", as: :security_lab_exploit

  get  "cpu-scheduler",            to: "cpu_scheduler#show",     as: :cpu_scheduler
  post "cpu-scheduler/simulate",   to: "cpu_scheduler#simulate", as: :cpu_scheduler_simulate

  get  "hotwire-lab",              to: "hotwire_lab#show", as: :hotwire_lab

  resources :incidents, only: %i[index show] do
    member do
      post :resolve
    end
  end

  get  "championships",                                to: "championships#index",              as: :championships
  get  "championships/interview-championship",          to: "championships#interview",          as: :interview_championship
  post "championships/interview-championship/answer",   to: "championships#answer_round",       as: :answer_interview_championship
  post "championships/interview-championship/reset",    to: "championships#reset_interview",    as: :reset_interview_championship
  get  "championships/developer-capstone",             to: "championships#developer_capstone", as: :developer_capstone
  post "championships/developer-capstone/submit",       to: "championships#submit_capstone_stage", as: :submit_capstone_stage
  post "championships/developer-capstone/reset",        to: "championships#reset_capstone",     as: :reset_developer_capstone

  get   "settings", to: "settings#show",   as: :settings
  patch "settings", to: "settings#update"

  resources :skills, only: %i[show], param: :id

  resources :topics, only: %i[show], param: :id do
    member do
      post :complete
    end
    # Prediction blocks are answered in place (spec 4).
    post "blocks/:block_id/predict", to: "predictions#create", as: :predict
  end

  resources :challenges, only: %i[index show], param: :id do
    resources :attempts, only: %i[create], controller: "challenge_attempts"
    resource :hint, only: %i[create], controller: "hints"
  end

  # The AI tutor explains a specific attempt, so it hangs off the attempt.
  post "attempts/:attempt_id/explanation", to: "explanations#create",
       as: :attempt_explanation

  resources :algorithms, only: %i[index show], param: :id do
    member do
      get :trace
    end
  end

  resources :boss_battles, only: %i[index show], param: :id, path: "bosses" do
    member do
      post :start
    end
    resource :stage, only: %i[update], controller: "boss_stages"
  end

  resources :interviews, only: %i[index create show] do
    resources :answers, only: %i[create], controller: "interview_answers"
  end

  resources :questions, only: %i[show] do
    member do
      post :answer
    end
  end

  resources :revisions, only: %i[index show]
  resources :achievements, only: %i[index]

  # --- Admin -------------------------------------------------------------
  namespace :admin do
    root "dashboard#show"
    get "settings", to: "settings#show", as: :settings
    patch "settings", to: "settings#update"

    resources :users, only: %i[index show update]
    resources :topics
    resources :challenges
    resources :questions
    resources :audit_logs, only: %i[index]
    resources :technology_versions, only: %i[index update]
  end

  # Sidekiq's dashboard exposes job data, so it is admin-only.
  authenticated_admin = lambda do |request|
    user_id = request.cookie_jar.signed[Authentication::SESSION_COOKIE]
    session = Session.authenticate(user_id)
    session&.user&.admin?
  end
  constraints authenticated_admin do
    mount Sidekiq::Web => "/admin/sidekiq"
  end

  # --- Operations --------------------------------------------------------
  get "up", to: "rails/health#show", as: :rails_health_check
end
