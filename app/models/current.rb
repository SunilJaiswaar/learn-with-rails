# Request-scoped context, used by auditing and policies.
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :request_id, :ip_address
end
