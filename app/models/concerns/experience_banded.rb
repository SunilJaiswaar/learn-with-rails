# Interview depth must scale with the candidate's years of experience (spec 41).
module ExperienceBanded
  extend ActiveSupport::Concern

  BANDS = {
    junior: 0,        # 0-1 years
    associate: 1,     # 1-2 years
    mid: 2,           # 2-3 years
    senior: 3,        # 3-5 years
    staff: 4,         # 5-8 years
    principal: 5      # 8+ years
  }.freeze

  BAND_LABELS = {
    "junior" => "0-1 years",
    "associate" => "1-2 years",
    "mid" => "2-3 years",
    "senior" => "3-5 years",
    "staff" => "5-8 years",
    "principal" => "8+ years"
  }.freeze

  included do
    enum :experience_band, BANDS, validate: true
  end

  def experience_band_label
    BAND_LABELS.fetch(experience_band, experience_band.to_s)
  end
end
