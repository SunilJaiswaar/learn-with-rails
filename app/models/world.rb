# A themed region of the game map (spec 6).
class World < ApplicationRecord
  include Sluggable

  has_many :skills, dependent: :nullify
  has_many :curriculum_modules, dependent: :destroy
  has_many :boss_battles, dependent: :nullify
  has_many :topics, through: :curriculum_modules

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :accent_color, format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/ }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :name) }
end
