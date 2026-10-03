source "https://rubygems.org"

ruby "3.4.5"

# --- Core ---------------------------------------------------------------
gem "rails", "~> 8.1.4"
gem "pg", "~> 1.5"
gem "puma", "~> 8.0"
gem "bootsnap", require: false

# --- Asset pipeline / Hotwire -------------------------------------------
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

# --- Domain -------------------------------------------------------------
gem "bcrypt", "~> 3.1"          # password hashing
gem "pundit", "~> 2.5"          # authorization policies
gem "redis", "~> 5.4"           # cache + sidekiq backend
gem "sidekiq", "~> 7.3"         # background jobs
gem "kaminari", "~> 1.2"        # pagination
gem "rack-attack", "~> 6.8"     # rate limiting / brute-force protection

group :development, :test do
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.5"
  gem "dotenv-rails", "~> 3.2"
  gem "rubocop", "~> 1.91", require: false
  gem "rubocop-rails", "~> 2.38", require: false
  gem "rubocop-rails-omakase", require: false
  gem "brakeman", "~> 8.0", require: false
end

group :development do
  gem "web-console"
end
