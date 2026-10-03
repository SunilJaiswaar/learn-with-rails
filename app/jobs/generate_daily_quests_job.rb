# Builds tomorrow's mission for every active learner, so the dashboard has
# something waiting rather than generating it on first request.
class GenerateDailyQuestsJob < ApplicationJob
  queue_as :low

  ACTIVE_WINDOW = 30.days

  def perform
    User.where(last_seen_at: ACTIVE_WINDOW.ago..).find_each(batch_size: 100) do |user|
      Learning::QuestGenerator.new(user: user).call
    rescue StandardError => e
      # One learner's quest failing must not stop everyone else's.
      Rails.logger.error("quest generation failed for user #{user.id}: #{e.class}: #{e.message}")
    end
  end
end
