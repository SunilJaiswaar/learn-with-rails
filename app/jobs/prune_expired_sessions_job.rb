# Expired session rows serve no purpose and are a small liability.
class PruneExpiredSessionsJob < ApplicationJob
  queue_as :low

  def perform
    Session.expired.in_batches(of: 1_000).delete_all
  end
end
