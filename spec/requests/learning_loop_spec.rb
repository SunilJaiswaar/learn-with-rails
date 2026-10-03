require "rails_helper"

RSpec.describe "The learning loop", type: :request do
  let(:user) { create(:user) }
  let(:skill) { create(:skill) }
  let(:topic) { create(:topic, skill: skill, xp_award: 10) }
  let(:lesson) { create(:lesson, topic: topic) }

  before { sign_in_as(user) }

  describe "a prediction block" do
    let!(:block) { create(:lesson_block, :prediction, lesson: lesson) }

    it "awards XP for a correct prediction" do
      expect {
        post topic_predict_path(topic_id: topic.slug, block_id: block.id),
             params: { choice: 1 },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change { user.reload.xp_total }.by(20)

      expect(response.body).to include("Correct")
    end

    it "awards nothing for a wrong prediction but still reveals why" do
      expect {
        post topic_predict_path(topic_id: topic.slug, block_id: block.id),
             params: { choice: 0 },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.not_to change { user.reload.xp_total }

      expect(response.body).to include("Because of the second one")
    end

    it "records prediction evidence either way" do
      post topic_predict_path(topic_id: topic.slug, block_id: block.id),
           params: { choice: 0 },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      progress = SkillProgress.find_by(user: user, skill: skill)
      expect(progress.prediction_score).to be > 0
      expect(progress.implementation_score).to eq(0)
    end

    it "does not pay twice for the same prediction" do
      2.times do
        post topic_predict_path(topic_id: topic.slug, block_id: block.id),
             params: { choice: 1 },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      expect(user.reload.xp_total).to eq(20)
    end
  end

  describe "completing a mission" do
    before { create(:lesson_block, lesson: lesson) }

    it "awards XP and records understanding, but not mastery" do
      expect { post complete_topic_path(topic.slug) }
        .to change { user.reload.xp_total }.by(10)

      progress = SkillProgress.find_by(user: user, skill: skill)
      expect(progress.understanding_score).to be > 0
      expect(progress.mastery_level).not_to eq("mastered")
    end

    it "is idempotent" do
      post complete_topic_path(topic.slug)
      expect { post complete_topic_path(topic.slug) }
        .not_to change { user.reload.xp_total }
    end

    it "marks the mission complete for that learner" do
      post complete_topic_path(topic.slug)

      expect(topic.reload).to be_completed_by(user)
    end
  end

  describe "answering an interview question" do
    let!(:question) do
      create(:question, skill: skill,
             answer_key: { "keywords" => %w[index selectivity], "required" => [ "index" ] })
    end
    let!(:follow_up) do
      create(:question_follow_up, question: question, trigger_kind: "always",
             body: "Why does that help?")
    end

    it "grades the answer and shows which concepts were recognised" do
      post answer_question_path(question),
           params: { body: "An index improves selectivity so the planner reads fewer rows." },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include("index")
      expect(user.question_attempts.last).to be_correct
    end

    it "offers the follow-up probe an interviewer would ask next" do
      post answer_question_path(question),
           params: { body: "An index improves selectivity so fewer rows are read." },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include("Why does that help?")
    end

    it "caps the score when a required concept is missing" do
      post answer_question_path(question),
           params: { body: "It just makes everything much faster than before somehow." },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(user.question_attempts.last).not_to be_correct
      expect(user.reload.xp_total).to eq(0)
    end
  end
end
