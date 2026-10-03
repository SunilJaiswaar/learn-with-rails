require "rails_helper"

RSpec.describe "The tutor", type: :request do
  let(:user) { create(:user) }
  let(:challenge) { create(:challenge, :with_tests, :with_hints) }

  before { sign_in_as(user) }

  it "offers nothing to explain before the first run" do
    get challenge_path(challenge.slug)

    expect(response.body).to include("Run your code first")
  end

  it "offers an explanation once there is an attempt" do
    create(:challenge_attempt_stub_for_explainer, user: user, challenge: challenge)

    get challenge_path(challenge.slug)

    expect(response.body).to include("Explain my last run")
  end

  it "explains the learner's own attempt" do
    attempt = create(:challenge_attempt_stub_for_explainer,
                     user: user, challenge: challenge, status: :failed,
                     results: { "tests" => [ { "name" => "case", "passed" => false,
                                               "expected" => "5", "actual" => "6" } ] })

    post attempt_explanation_path(attempt_id: attempt.id),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/off-by-one/i)
  end

  it "refuses to explain another learner's attempt" do
    other = create(:challenge_attempt_stub_for_explainer,
                   user: create(:user), challenge: challenge)

    post attempt_explanation_path(attempt_id: other.id),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:not_found)
  end

  it "labels which backend produced the explanation" do
    attempt = create(:challenge_attempt_stub_for_explainer, user: user, challenge: challenge)

    post attempt_explanation_path(attempt_id: attempt.id),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.body).to include("rubric")
  end

  it "states that it will not write the fix" do
    attempt = create(:challenge_attempt_stub_for_explainer, user: user, challenge: challenge)

    post attempt_explanation_path(attempt_id: attempt.id),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.body).to match(/will not write the fix/i)
  end
end
