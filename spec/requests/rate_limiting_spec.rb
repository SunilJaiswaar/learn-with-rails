require "rails_helper"

# Rate limiting is a security control, so it gets its own spec with throttling
# explicitly enabled (spec 73).
RSpec.describe "Rate limiting", type: :request do
  let!(:user) { create(:user, email: "target@example.com") }

  # rack-attack's railtie registers the middleware itself. config/application.rb
  # used to register it again, which put it in the stack twice and counted every
  # request twice against every throttle — so the effective limits were half the
  # configured ones. Easy to reintroduce, invisible without this assertion.
  it "installs the throttle middleware exactly once" do
    names = Rails.application.middleware.map(&:name)
    expect(names.count("Rack::Attack")).to eq(1)
  end

  it "throttles repeated login attempts from one IP" do
    with_rack_attack do
      statuses = 13.times.map do
        post login_path, params: { email: user.email, password: "wrong" }
        response.status
      end

      expect(statuses).to include(429)
      expect(statuses.count(429)).to be >= 3
    end
  end

  it "tells a throttled client when to retry" do
    with_rack_attack do
      13.times { post login_path, params: { email: user.email, password: "wrong" } }

      expect(response.headers["Retry-After"]).to be_present
      expect(response.body).to include("Too many requests")
    end
  end

  it "never throttles the health check" do
    with_rack_attack do
      statuses = 20.times.map do
        get "/up"
        response.status
      end

      expect(statuses.uniq).to eq([ 200 ])
    end
  end

  it "throttles sandbox submissions by IP" do
    challenge = create(:challenge, :with_tests)
    sign_in_as(user)

    with_rack_attack do
      statuses = 35.times.map do
        post challenge_attempts_path(challenge_id: challenge.slug),
             params: { code: "def double(n) = n" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        response.status
      end

      expect(statuses).to include(429)
    end
  end
end
