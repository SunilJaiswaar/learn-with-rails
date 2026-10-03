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
