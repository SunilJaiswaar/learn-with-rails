FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "learner#{n}@example.com" }
    sequence(:name) { |n| "Learner #{n}" }
    password { "password-for-specs" }
    password_confirmation { "password-for-specs" }
    role { :learner }
    experience_band { :junior }

    trait :admin do
      role { :admin }
    end

    trait :author do
      role { :author }
    end

    after(:create) { |user| user.create_streak! unless user.streak }
  end
end
