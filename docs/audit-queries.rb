# Reproduces every measurement in docs/AUDIT.md.
#   RAILS_ENV=test bin/rails runner docs/audit-queries.rb
#
# Kept in the repo so the audit's numbers can be re-checked after any change
# rather than trusted. A claim in AUDIT.md that this script contradicts is
# the claim that is wrong.

def heading(text)
  puts
  puts text
  puts "-" * text.length
end

heading "ARCHITECTURE"
puts "models              #{Dir['app/models/*.rb'].size}"
puts "tables              #{ActiveRecord::Base.connection.tables.size}"
puts "controllers         #{Dir['app/controllers/**/*_controller.rb'].size}"
puts "service namespaces  #{Dir['app/services/*/'].size}"
puts "views               #{Dir['app/views/**/*.erb'].size}"
puts "public routes       #{Rails.application.routes.routes.map { |r| r.path.spec.to_s.sub('(.:format)', '') }.uniq.reject { |p| p.start_with?('/rails', '/admin') }.size}"

heading "CONTENT INVENTORY"
{
  "Worlds" => World, "Skills" => Skill, "Topics" => Topic,
  "LessonBlocks" => LessonBlock, "Challenges" => Challenge,
  "Questions" => Question, "QuestionFollowUps" => QuestionFollowUp,
  "Algorithms" => Algorithm, "BossBattles" => BossBattle,
  "InterviewTemplates" => InterviewTemplate, "QuestTemplates" => QuestTemplate,
  "Achievements" => Achievement, "Technologies" => Technology,
  "TechnologyVersions" => TechnologyVersion, "LearningPaths" => LearningPath,
  "CurriculumModules" => CurriculumModule, "Lessons" => Lesson
}.each { |name, klass| puts "#{name.ljust(20)} #{klass.count}" }
puts "Projects             0 (no such entity)"
puts "challenges by lang   #{Challenge.group(:language).count.inspect}"

heading "C1 — content depth per skill"
floor = Skill.all.count do |s|
  s.topics.count == 1 && s.challenges.count == 2 && s.questions.count == 1
end
puts "skills at the exact definition-of-done floor (1 mission / 2 challenges / 1 question): #{floor} of #{Skill.count}"
Skill.includes(:topics, :challenges, :questions).find_each do |s|
  next if s.topics.count == 1 && s.challenges.count == 2 && s.questions.count == 1

  puts "  deeper: #{s.slug.ljust(24)} #{s.topics.count}/#{s.challenges.count}/#{s.questions.count}"
end

heading "C2 — Rails curriculum coverage"
puts "skills matching rails      #{Skill.where('slug ILIKE ?', '%rail%').count}"
puts "topics mentioning Rails    #{Topic.where('name ILIKE ?', '%rails%').count}"
puts "challenges on Rails/AR     #{Challenge.where('title ILIKE ? OR title ILIKE ?', '%rails%', '%active%').count}"
puts "questions mentioning Rails #{Question.where('body ILIKE ?', '%Rails%').count}"

heading "C3 — named technologies with zero skill"
probe = %w[python kafka zookeeper machine llm rag agent elastic docker aws
           linux typescript react angular mysql statistics pandas numpy]
missing = probe.reject { |t| Skill.where('slug ILIKE ?', "%#{t}%").exists? }
puts "#{missing.size} of #{probe.size}: #{missing.join(', ')}"

heading "D1 — CurriculumModule vs Skill isomorphism"
puts "modules #{CurriculumModule.count}  skills #{Skill.count}  topics #{Topic.count}"
puts "distinct (module, skill) pairs: #{Topic.distinct.pluck(:curriculum_module_id, :skill_id).size}"
puts "modules holding exactly one topic: #{CurriculumModule.joins(:topics).group('curriculum_modules.id').count.values.count(1)}"

heading "D2 — Lesson is a 1:1 pass-through"
puts "lessons per topic (distinct counts): #{Topic.joins(:lessons).group('topics.id').count.values.uniq.inspect}"
puts "lesson_blocks parented to a Lesson: #{LessonBlock.where.not(lesson_id: nil).count} of #{LessonBlock.count}"

heading "X1 — does anything gate on prerequisites?"
puts "SkillDependency rows: #{SkillDependency.count}"
gating = `grep -rln "prerequisite" app/controllers/ 2>/dev/null`.split("\n")
puts "controllers referencing prerequisites: #{gating.inspect}"
puts "(skills_controller only includes them for display — nothing blocks access)"

heading "X2 — mastery states"
puts "present:  #{SkillProgress::MASTERY_LEVELS.keys.join(' / ')} (#{SkillProgress::MASTERY_LEVELS.size})"
puts "required: LOCKED / AVAILABLE / STARTED / PRACTICING / UNDERSTOOD / APPLIED / VALIDATED / MASTERED / REVIEW_REQUIRED (9)"

heading "X7 — spec coverage holes"
%w[content models requests services system].each do |dir|
  puts "spec/#{dir.ljust(10)} #{Dir["spec/#{dir}/**/*_spec.rb"].size} files"
end
puts "capybara in Gemfile: #{File.read('Gemfile').match?(/capybara|selenium/) ? 'yes' : 'NO'}"

heading "U4 — responsive / a11y signals"
css = File.read("app/assets/stylesheets/application.css")
puts "@media queries: #{css.scan('@media').size}"
