require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include AuthenticationHelpers, type: :request
  config.include SandboxHelpers
  config.include RackAttackHelpers, type: :request
  config.include ActiveSupport::Testing::TimeHelpers
  config.include SqlSandboxHelpers
  config.include ContentHelpers

  # Provisioned once, outside any example transaction, so the separate
  # sandbox connection can see the committed schema.
  config.before(:suite) { SqlSandboxHelpers.provision! }

  # Content specs assert against seeded data, which makes the request suite
  # non-hermetic (a seeded achievement awards XP and breaks exact-delta
  # assertions). They are opt-in, and CI runs them in their own step after
  # seeding.
  config.filter_run_excluding(:content) unless ENV["RUN_CONTENT_SPECS"]
end
