require "rails_helper"

# A SQL challenge end to end: real query, real execution, real grading.
RSpec.describe "SQL challenges", type: :request do
  let(:user) { create(:user) }
  let(:skill) { create(:skill) }

  let(:challenge) do
    create(:challenge, skill: skill, language: :sql, challenge_type: :implement,
           xp_award: 40, time_limit_ms: 2_000,
           title: "Count the employees",
           prompt: "Return the number of employees.",
           reference_solution: "SELECT count(*) FROM employees",
           metadata: { "ordered" => false, "requires" => [], "forbids" => [] })
  end

  before do
    skip "SQL playground unavailable on this host" unless sql_sandbox_available?
    create(:challenge_test, challenge: challenge, position: 0,
           name: "returns the expected rows", call_expression: nil,
           expected: JSON.generate([ [ "8" ] ]))
    sign_in_as(user)
  end

  def submit(sql)
    post challenge_attempts_path(challenge_id: challenge.slug),
         params: { code: sql },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "shows the schema so the learner knows what to query" do
    get challenge_path(challenge.slug)

    expect(response.body).to include("Tables you can query")
    expect(response.body).to include("employees")
    expect(response.body).to include("PostgreSQL")
  end

  it "passes a correct query and awards XP once" do
    expect { submit("SELECT count(*) FROM employees") }
      .to change { user.reload.xp_total }.by(40)

    expect(user.challenge_attempts.last).to be_passed

    expect { submit("SELECT count(*) FROM employees") }
      .not_to change { user.reload.xp_total }
  end

  it "fails a wrong query and awards nothing" do
    expect { submit("SELECT count(*) FROM departments") }
      .not_to change { user.reload.xp_total }

    expect(user.challenge_attempts.last).to be_failed
  end

  it "renders the returned rows beside what was expected" do
    submit("SELECT count(*) FROM departments")

    expect(response.body).to include("Your result")
    expect(response.body).to include("Expected")
  end

  it "does not reveal the expected rows on a pass" do
    submit("SELECT count(*) FROM employees")

    expect(response.body).not_to include("Expected")
  end

  it "rejects a write attempt before it reaches the database" do
    submit("DELETE FROM employees")

    expect(user.challenge_attempts.last).to be_rejected
    expect(response.body).to match(/Only a SELECT/)
  end

  it "reports a permission error when reaching for application tables" do
    submit("SELECT email FROM public.users")

    attempt = user.challenge_attempts.last
    expect(attempt.status).to eq("error")
    expect(attempt.stderr).to match(/permission denied/i)
  end

  it "records implementation evidence against the skill" do
    submit("SELECT count(*) FROM employees")

    progress = SkillProgress.find_by(user: user, skill: skill)
    expect(progress.implementation_score).to be > 0
  end

  it "skips the Ruby code reviewer, which has nothing to say about SQL" do
    submit("SELECT count(*) FROM employees")

    expect(user.challenge_attempts.last.review).to eq({})
  end
end
