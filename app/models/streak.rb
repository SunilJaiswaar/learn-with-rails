# Streaks reward returning, but only a day with real activity counts.
class Streak < ApplicationRecord
  belongs_to :user

  validates :user_id, uniqueness: true
  validates :current_length, :longest_length,
            numericality: { greater_than_or_equal_to: 0 }

  def register_activity!(today = Date.current)
    return self if last_active_on == today

    self.current_length = if last_active_on == today - 1
                            current_length + 1
    else
                            1
    end
    self.longest_length = [ longest_length, current_length ].max
    self.last_active_on = today
    save!
    self
  end

  # A streak is live only if the user was active today or yesterday.
  def active?
    last_active_on.present? && last_active_on >= Date.current - 1
  end

  def display_length
    active? ? current_length : 0
  end
end
