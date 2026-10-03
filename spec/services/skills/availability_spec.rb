require "rails_helper"

RSpec.describe Skills::Availability do
  let(:user) { create(:user) }
  let(:basics) { create(:skill) }
  let(:joins) { create(:skill) }

  def availability(skill, as: user)
    described_class.new(user: as, skill: skill).call
  end

  context "a skill with no prerequisites" do
    it "is available" do
      expect(availability(basics)).to be_available
    end

    it "reports nothing missing and no time cost" do
      result = availability(basics)
      expect(result.missing).to be_empty
      expect(result.estimated_minutes).to be_zero
    end
  end

  context "a skill whose prerequisite is untouched" do
    before { SkillDependency.create!(skill: joins, prerequisite: basics) }

    it "is not available" do
      expect(availability(joins)).not_to be_available
    end

    it "names the missing prerequisite" do
      expect(availability(joins).missing_skills).to eq([ basics ])
    end

    it "reports the prerequisite as untested rather than guessing" do
      expect(availability(joins).missing.first.mastery_level).to eq("untested")
    end
  end

  context "as mastery on the prerequisite grows" do
    before { SkillDependency.create!(skill: joins, prerequisite: basics) }

    it "stays locked at weak" do
      create(:skill_progress, user: user, skill: basics, mastery_level: :weak)
      expect(availability(joins)).not_to be_available
    end

    it "opens at developing" do
      create(:skill_progress, user: user, skill: basics, mastery_level: :developing)
      expect(availability(joins)).to be_available
    end

    it "stays open at mastered" do
      create(:skill_progress, user: user, skill: basics, mastery_level: :mastered)
      expect(availability(joins)).to be_available
    end
  end

  context "with two prerequisites" do
    let(:indexing) { create(:skill) }

    before do
      SkillDependency.create!(skill: joins, prerequisite: basics)
      SkillDependency.create!(skill: joins, prerequisite: indexing)
    end

    it "requires both" do
      create(:skill_progress, user: user, skill: basics, mastery_level: :strong)
      result = availability(joins)

      expect(result).not_to be_available
      expect(result.met.map(&:skill)).to eq([ basics ])
      expect(result.missing_skills).to eq([ indexing ])
    end

    it "opens once both are demonstrated" do
      create(:skill_progress, user: user, skill: basics, mastery_level: :developing)
      create(:skill_progress, user: user, skill: indexing, mastery_level: :developing)

      expect(availability(joins)).to be_available
    end
  end

  describe "#estimated_minutes" do
    before { SkillDependency.create!(skill: joins, prerequisite: basics) }

    it "sums the missing prerequisites' published missions" do
      module_for = create(:curriculum_module)
      create(:topic, skill: basics, curriculum_module: module_for, estimated_minutes: 12)
      create(:topic, skill: basics, curriculum_module: module_for, estimated_minutes: 8)

      expect(availability(joins).estimated_minutes).to eq(20)
    end

    it "ignores an unpublished mission, which cannot be taken" do
      module_for = create(:curriculum_module)
      create(:topic, skill: basics, curriculum_module: module_for, estimated_minutes: 12)
      create(:topic, skill: basics, curriculum_module: module_for,
                     estimated_minutes: 99, published: false)

      expect(availability(joins).estimated_minutes).to eq(12)
    end

    it "reports zero for a prerequisite with no missions rather than inventing a number" do
      expect(availability(joins).estimated_minutes).to be_zero
    end
  end

  describe "staff" do
    before { SkillDependency.create!(skill: joins, prerequisite: basics) }

    it "lets an admin through so locked content can be reviewed" do
      admin = create(:user, role: :admin)
      expect(availability(joins, as: admin)).to be_available
    end

    it "lets an author through" do
      author = create(:user, role: :author)
      expect(availability(joins, as: author)).to be_available
    end

    it "says the pass was an override rather than implying it was earned" do
      admin = create(:user, role: :admin)
      expect(availability(joins, as: admin)).to be_staff_override
    end

    it "does not claim an override when the admin genuinely satisfied it" do
      admin = create(:user, role: :admin)
      create(:skill_progress, user: admin, skill: basics, mastery_level: :strong)

      expect(availability(joins, as: admin)).not_to be_staff_override
    end

    it "does not treat a learner as staff" do
      expect(availability(joins)).not_to be_staff_override
    end
  end

  describe "without a user" do
    before { SkillDependency.create!(skill: joins, prerequisite: basics) }

    it "treats a locked skill as locked rather than crashing" do
      expect(availability(joins, as: nil)).not_to be_available
    end

    it "leaves an unlocked skill open" do
      expect(availability(basics, as: nil)).to be_available
    end
  end

  it "uses the same rule as the skill map" do
    expect(Skills::TreeBuilder::UNLOCK_LEVELS).to eq(Skills::UnlockRule::LEVELS)
  end
end
