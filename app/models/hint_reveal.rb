class HintReveal < ApplicationRecord
  belongs_to :user
  belongs_to :hint

  validates :hint_id, uniqueness: { scope: :user_id }
end
