# The hermetic suite runs against an unseeded database and the content suite
# against a seeded one, so any spec that needs a record at a *known* slug must
# tolerate the seed having already created it. Creating it blindly raises on
# the uniqueness validation and makes the spec order-dependent.
module ContentHelpers
  def skill_at(slug, **attributes)
    find_or_build(Skill, :skill, slug, attributes)
  end

  def world_at(slug, **attributes)
    find_or_build(World, :world, slug, attributes)
  end

  def technology_at(slug, **attributes)
    find_or_build(Technology, :technology, slug, attributes)
  end

  def roadmap_at(slug, **attributes)
    find_or_build(LearningPath, :learning_path, slug, attributes)
  end

  def without_skill(slug)
    Skill.where(slug: slug).destroy_all
  end

  # The seed ships real prerequisite edges, so a spec about anything *other*
  # than locking has to say which skills it wants open.
  def unlocked!(*skills)
    SkillDependency.where(skill: skills).destroy_all
  end

  def depends_on!(skill, prerequisite)
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: prerequisite)
  end

  private

  # Updates the attributes on an existing record so a spec asserting on a
  # name gets the name it asked for even when the seed chose another.
  def find_or_build(klass, factory, slug, attributes)
    existing = klass.find_by(slug: slug)
    return FactoryBot.create(factory, slug: slug, **attributes) if existing.nil?

    existing.update!(**attributes) if attributes.any?
    existing
  end
end
