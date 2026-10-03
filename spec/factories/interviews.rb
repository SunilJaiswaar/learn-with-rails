FactoryBot.define do
  factory :interview do
    user
    interview_template
    status { :in_progress }
    pressure_mode { :normal }
    experience_band { :junior }
    started_at { Time.current }
  end

  factory :interview_question do
    interview
    question
    sequence(:position)
  end
end
