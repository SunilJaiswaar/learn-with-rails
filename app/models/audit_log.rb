# Admin and security-relevant actions are recorded (spec 73).
class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def self.record!(actor:, action:, auditable: nil, metadata: {}, ip_address: nil)
    create!(actor: actor, action: action, auditable: auditable,
            metadata: metadata, ip_address: ip_address)
  end
end
