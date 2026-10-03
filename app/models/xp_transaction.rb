# An append-only ledger. The user's xp_total is a cached sum of these rows, so
# XP can always be audited and recomputed.
class XpTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :source, polymorphic: true, optional: true

  validates :amount, numericality: { other_than: 0 }
  validates :reason, presence: true
  validates :idempotency_key, uniqueness: { scope: :user_id }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :earned, -> { where(amount: 1..) }
  scope :since, ->(time) { where(created_at: time..) }
end
