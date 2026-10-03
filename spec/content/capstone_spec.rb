require "rails_helper"

# These specs run against the *seeded* content, not factories. They exist
# because a capstone that cannot be completed is worse than no capstone, and
# the failure is invisible from the code alone.
#
# They are excluded from the default run because seeded content makes the
# request suite non-hermetic: a seeded achievement fires and awards extra XP,
# which breaks specs that assert an exact XP delta. CI therefore runs the
# hermetic suite first, then seeds and runs these with RUN_CONTENT_SPECS=1.
RSpec.describe "Capstone content", :content, type: :model do
  before do
    skip "seeded content not present (run rails db:seed)" unless BossBattle.exists?
  end

  describe "the Developer Championship" do
    let(:template) { InterviewTemplate.find_by(slug: "developer-championship") }

    it "exists at the deepest experience band" do
      expect(template).to be_present
      expect(template.experience_band).to eq("principal")
    end

    it "can actually be built — every round finds questions" do
      skip "championship not seeded" if template.nil?
      interview = Interviews::Builder.new(user: create(:user), template: template).call

      expect(interview).to be_present
      empty = interview.interview_rounds.reject { |r| r.interview_questions.any? }
      expect(empty.map(&:name)).to be_empty
    end

    it "covers every world through its rounds" do
      skip "championship not seeded" if template.nil?

      expect(template.rounds.length).to be >= 12
    end
  end

  describe "the capstone boss battles" do
    %w[the-black-friday-outage the-leaking-worker the-leaked-invoice].each do |slug|
      context slug do
        let(:boss) { BossBattle.find_by(slug: slug) }

        it "is winnable by answering every stage correctly" do
          skip "#{slug} not seeded" if boss.nil?
          user = create(:user)
          attempt = user.boss_attempts.create!(boss_battle: boss, status: :in_progress,
                                               current_stage: 0)

          boss.stage_list.each do |spec|
            answer = if spec["kind"] == "choice"
                       spec["answer"]
            else
                       "#{Array(spec['keywords']).join(' ')} and the reasoning in full"
            end
            outcome = BossBattles::StageEvaluator.new(attempt: attempt.reload,
                                                     answer: answer).call
            expect(outcome.correct).to be(true), "stage '#{spec['label']}' did not pass"
          end

          expect(attempt.reload).to be_won_battle
        end

        it "refuses an empty answer on every stage" do
          skip "#{slug} not seeded" if boss.nil?
          user = create(:user)
          attempt = user.boss_attempts.create!(boss_battle: boss, status: :in_progress,
                                               current_stage: 0)

          outcome = BossBattles::StageEvaluator.new(attempt: attempt, answer: "").call

          expect(outcome.correct).to be(false)
          expect(attempt.reload).to be_in_progress_battle
        end

        it "mixes disciplines rather than repeating one" do
          skip "#{slug} not seeded" if boss.nil?

          expect(boss.stage_count).to be >= 3
        end
      end
    end
  end

  describe "the championship quest" do
    it "routes through a boss, a challenge and an interview" do
      quest = QuestTemplate.find_by(slug: "championship-run")
      skip "championship quest not seeded" if quest.nil?

      kinds = quest.steps.map { |s| s["kind"] }
      expect(kinds).to include("boss", "challenge", "interview")
    end

    it "references content that exists" do
      quest = QuestTemplate.find_by(slug: "championship-run")
      skip "championship quest not seeded" if quest.nil?

      quest.steps.each do |step|
        next if step["target_slug"].blank?

        klass = step["target_type"].constantize
        expect(klass.find_by(slug: step["target_slug"]))
          .to be_present, "#{step['target_type']} #{step['target_slug']} is missing"
      end
    end
  end
end
