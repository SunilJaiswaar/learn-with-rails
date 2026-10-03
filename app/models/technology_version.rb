# Version-aware curriculum (spec 60): old versions stay available for interview
# preparation but are never presented as current knowledge.
class TechnologyVersion < ApplicationRecord
  belongs_to :technology

  enum :status, { current: 0, maintained: 1, deprecated: 2, eol: 3 },
       suffix: :status, validate: true

  has_many :topics, dependent: :nullify

  validates :number, presence: true,
                     uniqueness: { scope: :technology_id, case_sensitive: false }

  scope :supported, -> { where(status: %i[current maintained]) }
  scope :newest_first, -> { order(Arel.sql("released_on DESC NULLS LAST")) }

  def label
    "#{technology.name} #{number}"
  end

  def teachable_as_current?
    current_status? || maintained_status?
  end
end
