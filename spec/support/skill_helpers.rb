# The hermetic suite runs against an unseeded database and the content suite
# against a seeded one, so any spec that needs a skill at a *known* slug must
# tolerate the seed having already created it. Creating it blindly raises on
# the uniqueness validation and makes the spec order-dependent.
module SkillHelpers
  def skill_at(slug, **attributes)
    Skill.find_by(slug: slug) || FactoryBot.create(:skill, slug: slug, **attributes)
  end

  def without_skill(slug)
    Skill.where(slug: slug).destroy_all
  end
end
