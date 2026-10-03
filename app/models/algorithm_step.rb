class AlgorithmStep < ApplicationRecord
  belongs_to :algorithm

  validates :position, uniqueness: { scope: :algorithm_id }

  scope :ordered, -> { order(:position) }
end
