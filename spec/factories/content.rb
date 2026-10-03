FactoryBot.define do
  factory :world do
    sequence(:name) { |n| "World #{n}" }
    sequence(:slug) { |n| "world-#{n}" }
  end

  factory :technology do
    sequence(:name) { |n| "Tech #{n}" }
    sequence(:slug) { |n| "tech-#{n}" }
  end

  factory :technology_version do
    technology
    sequence(:number) { |n| "#{n}.0" }
    status { :current }
  end

  factory :skill do
    sequence(:name) { |n| "Skill #{n}" }
    sequence(:slug) { |n| "skill-#{n}" }
    world
    summary { "A testable skill." }
  end

  factory :curriculum_module do
    sequence(:name) { |n| "Module #{n}" }
    sequence(:slug) { |n| "module-#{n}" }
    world
  end

  factory :topic do
    sequence(:name) { |n| "Mission #{n}" }
    sequence(:slug) { |n| "mission-#{n}" }
    curriculum_module
    skill
    hook { "Something surprising happens." }
    summary { "A short mission." }
    estimated_minutes { 5 }
    xp_award { 10 }
  end

  factory :lesson do
    topic
    sequence(:title) { |n| "Lesson #{n}" }
    sequence(:slug) { |n| "lesson-#{n}" }
  end

  factory :lesson_block do
    lesson
    block_type { :prose }
    payload { { "body" => "Explanation text." } }

    trait :prediction do
      block_type { :prediction }
      payload do
        { "question" => "What happens?", "options" => %w[One Two],
          "answer" => 1, "explanation" => "Because of the second one." }
      end
    end
  end

  factory :challenge do
    sequence(:title) { |n| "Challenge #{n}" }
    sequence(:slug) { |n| "challenge-#{n}" }
    skill
    topic
    challenge_type { :implement }
    language { :ruby }
    difficulty { :easy }
    prompt { "Write a method called `double` that doubles its argument." }
    starter_code { "def double(n)\nend\n" }
    reference_solution { "def double(n)\n  n * 2\nend\n" }
    xp_award { 30 }

    trait :with_tests do
      after(:create) do |challenge|
        create(:challenge_test, challenge: challenge, name: "doubles 2",
               call_expression: "double(2)", expected: "4", position: 0)
        create(:challenge_test, challenge: challenge, name: "doubles 0",
               call_expression: "double(0)", expected: "0", position: 1)
      end
    end

    trait :with_hints do
      after(:create) do |challenge|
        create(:hint, challenge: challenge, level: :nudge, position: 0,
               body: "Think about multiplication.", xp_penalty: 2)
        create(:hint, challenge: challenge, level: :solution, position: 1,
               body: "Return n * 2.", xp_penalty: 8)
      end
    end
  end

  factory :challenge_test do
    challenge
    sequence(:name) { |n| "test #{n}" }
    call_expression { "double(2)" }
    expected { "4" }
  end

  factory :hint do
    challenge
    level { :nudge }
    body { "A gentle nudge." }
    xp_penalty { 2 }
  end

  factory :question do
    skill
    body { "Why is an index useful?" }
    question_type { "scenario" }
    experience_band { :junior }
    answer_key { { "keywords" => %w[index lookup selectivity], "required" => [ "index" ] } }
    model_answer { "An index avoids a full scan." }

    trait :mcq do
      question_type { "mcq" }
      options { [ "Because it scans", "Because it avoids a scan" ] }
      answer_key { { "correct_index" => 1 } }
    end
  end

  factory :question_follow_up do
    question
    body { "Why does that help?" }
    trigger_kind { "always" }
    answer_key { { "keywords" => %w[selectivity rows] } }
  end

  factory :achievement do
    sequence(:name) { |n| "Achievement #{n}" }
    sequence(:slug) { |n| "achievement-#{n}" }
    description { "Do a thing." }
    rule_key { "challenges_solved" }
    threshold { 1 }
    xp_reward { 25 }
  end

  factory :algorithm do
    sequence(:name) { |n| "Algorithm #{n}" }
    slug { "bubble-sort" }
    category { "sorting" }
    visualizer_kind { "array" }
    skill
  end

  factory :quest_template do
    sequence(:name) { |n| "Quest #{n}" }
    sequence(:slug) { |n| "quest-#{n}" }
    briefing { "Production is on fire." }
    xp_reward { 350 }
    step_specs { [ { "label" => "Do the thing", "kind" => "challenge" } ] }
  end

  factory :boss_battle do
    sequence(:title) { |n| "Boss #{n}" }
    sequence(:slug) { |n| "boss-#{n}" }
    boss_name { "The Tester" }
    scenario { "Something is badly wrong." }
    skill
    stages do
      [ { "label" => "Diagnose", "kind" => "open",
          "prompt" => "What went wrong?", "keywords" => %w[duplicate join],
          "explanation" => "Row multiplication." } ]
    end
  end

  factory :interview_template do
    sequence(:name) { |n| "Track #{n}" }
    sequence(:slug) { |n| "track-#{n}" }
    experience_band { :junior }
    round_specs { [ { "name" => "Round 1", "count" => 1 } ] }
  end
end
