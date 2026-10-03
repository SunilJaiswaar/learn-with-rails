require "rails_helper"

# The lock state was computed and rendered on the skill map but never enforced,
# so a locked skill was served to anyone who typed its URL (audit X1). These
# specs pin both halves: the refusal, and the deliberate decision about what
# stays open.
RSpec.describe "The prerequisite gate", type: :request do
  let(:user) { create(:user) }
  let(:basics) { create(:skill) }
  let(:locked_skill) { create(:skill) }
  let(:curriculum_module) { create(:curriculum_module) }

  before do
    sign_in_as(user)
    SkillDependency.create!(skill: locked_skill, prerequisite: basics)
  end

  def satisfy_prerequisite!
    create(:skill_progress, user: user, skill: basics, mastery_level: :developing)
  end

  describe "a locked skill page" do
    it "is refused with 403 rather than served" do
      get skill_path(locked_skill.slug)
      expect(response).to have_http_status(:forbidden)
    end

    it "explains what to learn first instead of just refusing" do
      get skill_path(locked_skill.slug)

      expect(response.body).to include("You need one concept first")
      expect(response.body).to include(basics.name)
      expect(response.body).to include(skill_path(basics.slug))
    end

    it "offers the missing skill as the next action" do
      get skill_path(locked_skill.slug)
      expect(response.body).to include("Start #{basics.name}")
    end

    it "opens once the prerequisite reaches developing mastery" do
      satisfy_prerequisite!

      get skill_path(locked_skill.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("You need one concept first")
    end

    it "stays locked while the prerequisite is only weak" do
      create(:skill_progress, user: user, skill: basics, mastery_level: :weak)

      get skill_path(locked_skill.slug)

      expect(response).to have_http_status(:forbidden)
    end

    it "quotes a time estimate from the prerequisite's own missions" do
      create(:topic, skill: basics, curriculum_module: curriculum_module, estimated_minutes: 9)

      get skill_path(locked_skill.slug)

      expect(response.body).to include("9 minutes")
    end

    it "answers JSON with a machine-readable reason" do
      get skill_path(locked_skill.slug), as: :json

      expect(response).to have_http_status(:forbidden)
      body = response.parsed_body
      expect(body["error"]).to eq("locked")
      expect(body["missing"]).to eq([ basics.slug ])
    end
  end

  describe "a mission in a locked skill" do
    let(:topic) { create(:topic, skill: locked_skill, curriculum_module: curriculum_module) }

    it "is refused" do
      get topic_path(topic.slug)
      expect(response).to have_http_status(:forbidden)
    end

    # Without gating #complete, a locked mission could still be completed by
    # POSTing to it, which awards XP.
    it "cannot be completed for XP by POSTing straight to it" do
      expect { post complete_topic_path(topic.slug) }
        .not_to change { user.reload.xp_total }

      expect(response).to have_http_status(:forbidden)
      expect(user.topic_completions.finished.count).to be_zero
    end

    it "becomes completable once unlocked" do
      satisfy_prerequisite!

      post complete_topic_path(topic.slug)

      expect(response).to have_http_status(:found)
      expect(user.topic_completions.finished.count).to eq(1)
    end
  end

  describe "a challenge in a locked skill" do
    let(:challenge) { create(:challenge, skill: locked_skill) }

    it "is refused" do
      get challenge_path(challenge.slug)
      expect(response).to have_http_status(:forbidden)
    end

    it "cannot be submitted to, so no XP is reachable" do
      expect {
        post challenge_attempts_path(challenge.slug), params: { code: "x = 1" }
      }.not_to change { ChallengeAttempt.count }

      expect(response).to have_http_status(:forbidden)
    end

    it "accepts a submission once unlocked" do
      satisfy_prerequisite!

      post challenge_attempts_path(challenge.slug), params: { code: "x = 1" }

      expect(response).not_to have_http_status(:forbidden)
    end
  end

  describe "a boss battle in a locked skill" do
    let(:boss) { create(:boss_battle, skill: locked_skill) }

    it "is refused" do
      get boss_battle_path(boss.slug)
      expect(response).to have_http_status(:forbidden)
    end

    it "cannot be started" do
      expect { post start_boss_battle_path(boss.slug) }
        .not_to change { BossAttempt.count }

      expect(response).to have_http_status(:forbidden)
    end
  end

  # The deliberate line: gate what measures and rewards, leave open what
  # explores and introduces. These specs exist so the decision is visible and
  # cannot be reversed silently.
  describe "what deliberately stays open" do
    it "leaves the engineering labs reachable, since discovering precedes understanding" do
      skill_at("redis-caching", name: "Redis & Caching")

      get redis_vault_path

      expect(response).to have_http_status(:ok)
    end

    it "leaves the interview arena reachable for someone interviewing tomorrow" do
      question = create(:question, skill: locked_skill)

      get question_path(question.id)

      expect(response).to have_http_status(:ok)
    end

    it "still lists a locked skill on the skill map, shown as locked" do
      get skill_map_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(locked_skill.name)
      expect(response.body).to include("skill-node--locked")
    end

    # Scoped with the index's own skill filter, because the seeded catalogue
    # contains plenty of other locked challenges.
    it "still lists a locked challenge on the challenges index, marked locked" do
      challenge = create(:challenge, skill: locked_skill)

      get challenges_path(skill_id: locked_skill.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(challenge.title)
      expect(response.body).to include("🔒 Locked")
    end

    it "does not mark an unlocked challenge as locked" do
      challenge = create(:challenge, skill: basics)

      get challenges_path(skill_id: basics.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(challenge.title)
      expect(response.body).not_to include("🔒 Locked")
    end
  end

  describe "staff" do
    it "lets an admin view locked content for review" do
      delete logout_path
      sign_in_as(create(:user, role: :admin))

      get skill_path(locked_skill.slug)

      expect(response).to have_http_status(:ok)
    end

    it "lets an author view locked content" do
      delete logout_path
      sign_in_as(create(:user, role: :author))

      get skill_path(locked_skill.slug)

      expect(response).to have_http_status(:ok)
    end
  end

  it "leaves a skill with no prerequisites open to everyone" do
    get skill_path(basics.slug)
    expect(response).to have_http_status(:ok)
  end
end
