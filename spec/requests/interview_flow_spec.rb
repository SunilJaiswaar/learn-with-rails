require "rails_helper"

RSpec.describe "Interview flow", type: :request do
  let(:user) { create(:user, experience_band: :mid) }
  let(:skill) { create(:skill) }

  let!(:template) do
    create(:interview_template, experience_band: :mid, question_count: 2,
           round_specs: [ { "name" => "Fundamentals", "count" => 2 } ])
  end

  let!(:questions) do
    [
      create(:question, skill: skill, experience_band: :junior,
             answer_key: { "keywords" => %w[index rows], "required" => [ "index" ] }),
      create(:question, skill: skill, experience_band: :mid,
             body: "How would you find a slow query?",
             answer_key: { "keywords" => %w[explain analyze], "required" => [] })
    ]
  end

  before { sign_in_as(user) }

  def start_interview
    post interviews_path, params: { interview_template_id: template.id,
                                    pressure_mode: "normal" }
    Interview.last
  end

  it "builds an interview with rounds and questions" do
    interview = start_interview

    expect(interview.interview_questions.count).to eq(2)
    expect(interview.interview_rounds.first.name).to eq("Fundamentals")
    expect(response).to redirect_to(interview_path(interview))
  end

  it "does not ask a mid-level candidate questions above their band" do
    create(:question, skill: skill, experience_band: :principal,
           body: "Design a global exchange.")
    interview = start_interview

    bands = interview.questions.map(&:experience_band)
    expect(bands).not_to include("principal")
  end

  it "applies a per-question time limit in timed mode" do
    post interviews_path, params: { interview_template_id: template.id,
                                    pressure_mode: "rapid_fire" }

    expect(Interview.last.interview_questions.first.time_limit_seconds).to eq(45)
  end

  it "ignores an unknown pressure mode rather than failing" do
    post interviews_path, params: { interview_template_id: template.id,
                                    pressure_mode: "nonsense" }

    expect(Interview.last.pressure_mode).to eq("normal")
  end

  it "records an answer and grades it" do
    interview = start_interview
    # Target a known question: the builder randomises order within a band.
    current = interview.interview_questions.find_by!(question: questions.first)

    post interview_answers_path(interview_id: interview.id),
         params: { interview_question_id: current.id,
                   body: "I would add an index so the planner reads fewer rows." }

    answer = current.reload.interview_answer
    expect(answer).to be_present
    expect(answer.score).to be > 0
  end

  it "inserts a follow-up probe when the answer invites one" do
    create(:question_follow_up, question: questions.first, trigger_kind: "always",
           body: "Why does that reduce the row count?")
    interview = start_interview
    current = interview.interview_questions.find_by(question: questions.first)

    expect {
      post interview_answers_path(interview_id: interview.id),
           params: { interview_question_id: current.id,
                     body: "An index means fewer rows are scanned." }
    }.to change { interview.interview_questions.count }.by(1)

    expect(interview.interview_questions.last).to be_follow_up
  end

  it "completes the interview and produces competency feedback" do
    interview = start_interview

    # Answer everything, including any probes inserted along the way.
    20.times do
      current = interview.reload.current_question
      break if current.nil?

      post interview_answers_path(interview_id: interview.id),
           params: { interview_question_id: current.id,
                     body: "I would use EXPLAIN ANALYZE to inspect the plan, " \
                           "then add an index so fewer rows are read." }
    end

    interview.reload
    expect(interview).to be_completed_interview
    expect(interview.competency_scores).to be_present
    expect(interview.feedback["strong_areas"]).to be_an(Array)
    expect(interview.xp_awarded).to be > 0
  end

  it "never promises a pass or a job" do
    interview = start_interview
    while (current = interview.reload.current_question)
      post interview_answers_path(interview_id: interview.id),
           params: { interview_question_id: current.id, body: "An index helps." }
    end

    get interview_path(interview)

    expect(response.body).to include("not a prediction about any")
    expect(response.body).not_to match(/you will (?:definitely )?pass/i)
  end

  it "records explanation evidence, not implementation" do
    interview = start_interview
    current = interview.interview_questions.find_by!(question: questions.first)

    post interview_answers_path(interview_id: interview.id),
         params: { interview_question_id: current.id,
                   body: "An index reduces the rows the planner must read." }

    progress = SkillProgress.find_by(user: user, skill: skill)
    expect(progress.explanation_score).to be > 0
    expect(progress.implementation_score).to eq(0)
  end

  it "refuses to answer the same question twice" do
    interview = start_interview
    current = interview.interview_questions.find_by!(question: questions.first)

    post interview_answers_path(interview_id: interview.id),
         params: { interview_question_id: current.id, body: "First answer with index." }
    post interview_answers_path(interview_id: interview.id),
         params: { interview_question_id: current.id, body: "Second answer." }

    expect(current.reload.interview_answer.body).to include("First answer")
  end
end
