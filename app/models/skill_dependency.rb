class SkillDependency < ApplicationRecord
  belongs_to :skill
  belongs_to :prerequisite, class_name: "Skill"

  validates :prerequisite_id, uniqueness: { scope: :skill_id }
  validate :must_not_be_self
  validate :must_not_create_cycle

  private

  def must_not_be_self
    errors.add(:prerequisite_id, "cannot be the skill itself") if skill_id == prerequisite_id
  end

  # The skill tree must stay a DAG, otherwise unlock resolution never terminates.
  def must_not_create_cycle
    return if skill_id.blank? || prerequisite_id.blank?
    return unless Skills::CycleDetector.new(skill_id: skill_id,
                                            prerequisite_id: prerequisite_id).cycle?

    errors.add(:prerequisite_id, "would create a circular prerequisite chain")
  end
end
