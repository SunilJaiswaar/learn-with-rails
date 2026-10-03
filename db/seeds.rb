# Seeds are idempotent: every record is found-or-created by a stable slug, so
# `db:seed` can be re-run safely against an existing database.
require Rails.root.join("db/seeds/support")

puts "Seeding #{AppSetting.product_name rescue 'CodeQuest'}..."

# SQL challenges are authored by running their reference query against the
# playground, so the schema has to exist before the content loads. Dropping the
# database drops the schema with it, which is why this runs on every seed.
unless SqlExecution::SandboxSchema.provisioned?
  puts "  provisioning the SQL playground"
  SqlExecution::SandboxSchema.provision!
  SqlExecution::Runner.reset_pool!
end

ActiveRecord::Base.transaction do
  %w[
    01_foundation
    02_skills
    03_sql_joins
    04_ruby
    05_algorithms
    06_algorithm_records
    07_gamification
    09_loop_completion
    10_sql_basics
    11_sql_aggregation
    12_sql_loop_completion
    13_phase2_algorithms_git
    14_phase3_database
    15_phase3_stack
    16_phase4_frontend
    17_phase5_computer_science
    18_phase6_patterns_architecture
    08_demo_users
  ].each { |file| load Rails.root.join("db/seeds/#{file}.rb") }
end

puts "\nSeeded:"
{
  "Worlds" => World, "Skills" => Skill, "Missions" => Topic,
  "Lesson blocks" => LessonBlock, "Challenges" => Challenge,
  "Challenge tests" => ChallengeTest, "Hints" => Hint,
  "Questions" => Question, "Follow-ups" => QuestionFollowUp,
  "Algorithms" => Algorithm, "Achievements" => Achievement,
  "Quest templates" => QuestTemplate, "Boss battles" => BossBattle,
  "Interview tracks" => InterviewTemplate, "Users" => User
}.each { |label, klass| puts "  #{label.ljust(16)} #{klass.count}" }
puts "  #{'SQL challenges'.ljust(16)} #{Challenge.sql_language.count}"

incomplete = Topic.includes(:lessons, :challenges, :questions).reject(&:complete_content?)
if incomplete.any?
  puts "\nMissions missing part of the learning loop (spec 80):"
  incomplete.each do |topic|
    missing = topic.definition_of_done.reject { |_k, v| v }.keys
    puts "  #{topic.slug}: #{missing.join(', ')}"
  end
else
  puts "\nEvery mission satisfies the definition of done."
end
