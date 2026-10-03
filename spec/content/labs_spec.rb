require "rails_helper"

# The lab registry names skills by slug, so a renamed or unseeded skill
# silently orphans a lab: it keeps awarding XP but stops counting as evidence.
# Only the seeded content can prove the mapping still resolves.
RSpec.describe "Laboratory content", :content, type: :model do
  before do
    skip "seeded content not present (run rails db:seed)" unless Skill.exists?
  end

  it "maps every lab to a skill that exists" do
    expect(Labs::Catalogue.missing_skills).to be_empty,
      "labs point at skills that are not seeded: #{Labs::Catalogue.missing_skills.join(', ')}"
  end

  it "gives every mapped skill a reachable page" do
    Labs::Catalogue.all.each_value do |lab|
      skill = Skill.find_by(slug: lab[:skill])
      expect(skill.slug).to be_present, "#{lab[:name]} maps to a skill with no slug"
    end
  end

  it "reaches the labs from their skill, so they are discoverable in context" do
    Labs::Catalogue.all.each do |key, lab|
      expect(Labs::Catalogue.for_skill(lab[:skill])).to include(key)
    end
  end
end
