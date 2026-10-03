class Lesson < ApplicationRecord
  include Sluggable

  slug_from :title
  slug_unique_within :topic_id

  belongs_to :topic

  has_many :lesson_blocks, -> { order(:position) }, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(:position) }
end
