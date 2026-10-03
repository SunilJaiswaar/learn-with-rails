require "rails_helper"

RSpec.describe Labs::Catalogue do
  describe ".all" do
    it "gives every lab a skill, a dimension, a route and a summary" do
      described_class.all.each do |key, lab|
        expect(lab[:skill]).to be_present, "#{key} has no skill"
        expect(lab[:name]).to be_present, "#{key} has no name"
        expect(lab[:summary]).to be_present, "#{key} has no summary"
        expect(SkillProgress::DIMENSIONS).to include(lab[:dimension]),
                                             "#{key} has dimension #{lab[:dimension].inspect}"
        expect(Rails.application.routes.url_helpers).to respond_to(lab[:route]),
                                                        "#{key} points at missing route #{lab[:route]}"
      end
    end

    it "does not map two labs to the same skill" do
      skills = described_class.all.values.map { |lab| lab[:skill] }
      expect(skills.uniq.length).to eq(skills.length)
    end
  end

  describe ".find" do
    it "accepts a symbol or a string" do
      expect(described_class.find(:git_lab)).to eq(described_class.find("git_lab"))
    end

    it "returns nil for a lab that does not exist" do
      expect(described_class.find("not_a_lab")).to be_nil
    end
  end

  describe ".skill_for" do
    it "resolves the mapped skill record" do
      skill = create(:skill, slug: "git-fundamentals")
      expect(described_class.skill_for("git_lab")).to eq(skill)
    end

    it "returns nil when the lab key is unknown" do
      expect(described_class.skill_for("not_a_lab")).to be_nil
    end

    it "returns nil rather than guessing when the skill is absent" do
      expect(described_class.skill_for("git_lab")).to be_nil
    end
  end

  describe ".for_skill" do
    it "returns only the labs belonging to that skill" do
      labs = described_class.for_skill("web-security")
      expect(labs.keys).to eq([ "security_lab" ])
    end

    it "returns nothing for a skill with no lab" do
      expect(described_class.for_skill("skill-with-no-lab")).to be_empty
    end
  end

  describe ".missing_skills" do
    it "names the skills a lab points at that do not exist" do
      create(:skill, slug: "git-fundamentals")
      expect(described_class.missing_skills).not_to include("git-fundamentals")
      expect(described_class.missing_skills).to include("web-security")
    end
  end

  it "excludes the championship, which spans every skill" do
    expect(described_class.find("championship")).to be_nil
  end
end
