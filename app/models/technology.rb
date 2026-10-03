class Technology < ApplicationRecord
  include Sluggable

  has_many :technology_versions, dependent: :destroy
  has_many :skills, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :category, presence: true

  scope :ordered, -> { order(:position, :name) }

  def current_version
    technology_versions.current_status.order(released_on: :desc).first
  end
end
