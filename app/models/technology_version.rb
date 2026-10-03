# Version-aware curriculum (spec 60): old versions stay available for interview
# preparation but are never presented as current knowledge.
class TechnologyVersion < ApplicationRecord
  belongs_to :technology

  enum :status, { current: 0, maintained: 1, deprecated: 2, eol: 3 },
       suffix: :status, validate: true

  has_many :topics, dependent: :nullify

  validates :number, presence: true,
                     uniqueness: { scope: :technology_id, case_sensitive: false }

  # docs_url is rendered as a link_to href, so an admin typo of `javascript:`
  # would execute on click. Official documentation is always https, so the
  # scheme is an allow-list rather than a denylist of dangerous ones.
  validates :docs_url, format: { with: %r{\Ahttps://\S+\z},
                                 message: "must be an https:// URL" },
                       allow_blank: true

  scope :supported, -> { where(status: %i[current maintained]) }
  scope :newest_first, -> { order(Arel.sql("released_on DESC NULLS LAST")) }

  def label
    "#{technology.name} #{number}"
  end

  def teachable_as_current?
    current_status? || maintained_status?
  end

  # Guards data stored before the validation above existed. Returns nil rather
  # than an unsafe href so the view simply omits the link.
  def safe_docs_url
    docs_url.presence&.then { |url| url if url.match?(%r{\Ahttps://\S+\z}) }
  end
end
