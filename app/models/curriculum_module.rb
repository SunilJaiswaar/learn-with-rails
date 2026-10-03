# Named CurriculumModule because `Module` is a Ruby core class.
class CurriculumModule < ApplicationRecord
  include Sluggable

  belongs_to :world

  has_many :topics, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :name) }
end
