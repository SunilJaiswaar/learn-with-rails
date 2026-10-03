# Marks yesterday's unfinished quests expired so they stop appearing as open.
class ExpireStaleQuestsJob < ApplicationJob
  queue_as :low

  def perform(on: Date.current)
    Quest.where(status: :open).where(scheduled_on: ...on)
         .in_batches(of: 500) { |batch| batch.update_all(status: Quest.statuses[:expired]) }
  end
end
