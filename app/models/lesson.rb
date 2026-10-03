class Lesson < ApplicationRecord
  include Sluggable

  belongs_to :topic

  has_many :lesson_blocks, -> { order(:position) }, dependent: :destroy

  validates :title, presence: true
  validates :slug, uniqueness: { scope: :topic_id, case_sensitive: false }

  scope :ordered, -> { order(:position) }

  def self.slug_source
    :title
  end
end
