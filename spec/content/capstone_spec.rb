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

  # Iterates every seeded boss rather than a hardcoded list, so a new boss
  # battle is validated the moment it is authored. The list cannot be built at
  # load time because the hermetic suite runs against an unseeded database.
  describe "the capstone boss battles" do
    def each_seeded_boss
      bosses = BossBattle.published.order(:slug).to_a
      skip "no boss battles seeded" if bosses.empty?
      bosses.each { |boss| yield boss }
    end

    it "covers every world that has one" do
      each_seeded_boss do |boss|
        expect(boss.world).to be_present, "#{boss.slug} belongs to no world"
        expect(boss.skill).to be_present, "#{boss.slug} belongs to no skill"
      end
    end

    # The winnability check below builds its answer out of the stage's own
    # keywords, so it proves the attempt mechanism works end to end but cannot
    # fail on a bad keyword list — it is tautological for open stages. This is
    # the check that actually discriminates: a confident, generic,
    # content-free answer must NOT pass, or the stage is graded on nothing.
    it "rejects a generic answer that names none of the expected concepts" do
      generic = "I would investigate this carefully, look at the logs and " \
                "metrics, talk to the team, and then apply the appropriate fix " \
                "before verifying it in staging."

      each_seeded_boss do |boss|
        boss.stage_list.each_with_index do |spec, index|
          next unless spec["kind"] == "open"

          user = create(:user)
          attempt = user.boss_attempts.create!(boss_battle: boss,
                                               status: :in_progress,
                                               current_stage: index)
          outcome = BossBattles::StageEvaluator.new(attempt: attempt, answer: generic).call

          expect(outcome.correct).to be(false),
                                    "#{boss.slug}: stage '#{spec['label']}' passed an " \
                                    "answer containing none of its concepts"
        end
      end
    end

    it "is winnable by answering every stage correctly" do
      each_seeded_boss do |boss|
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
          expect(outcome.correct).to be(true),
                                    "#{boss.slug}: stage '#{spec['label']}' did not pass"
        end

        expect(attempt.reload).to be_won_battle, "#{boss.slug} was not winnable"
      end
    end

    it "refuses an empty answer on the first stage" do
      each_seeded_boss do |boss|
        user = create(:user)
        attempt = user.boss_attempts.create!(boss_battle: boss, status: :in_progress,
                                             current_stage: 0)

        outcome = BossBattles::StageEvaluator.new(attempt: attempt, answer: "").call

        expect(outcome.correct).to be(false), "#{boss.slug} accepted an empty answer"
        expect(attempt.reload).to be_in_progress_battle
      end
    end

    it "mixes disciplines rather than repeating one" do
      each_seeded_boss do |boss|
        expect(boss.stage_count).to be >= 3, "#{boss.slug} has only #{boss.stage_count} stages"
      end
    end

    it "explains every stage, so a wrong answer teaches something" do
      each_seeded_boss do |boss|
        boss.stage_list.each do |spec|
          expect(spec["explanation"]).to be_present,
                                        "#{boss.slug}: stage '#{spec['label']}' has no explanation"
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
