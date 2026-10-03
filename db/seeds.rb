# Seeds are idempotent: every record is found-or-created by a stable slug, so
# `db:seed` can be re-run safely against an existing database.
require Rails.root.join("db/seeds/support")

puts "Seeding #{AppSetting.product_name rescue 'CodeQuest'}..."

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
