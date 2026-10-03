puts "  demo accounts"

# Demo accounts exist only outside production. Passwords come from the
# environment when set, so seeded credentials are never a shipped secret.
if Rails.env.production?
  puts "    skipped in production"
else
  admin_password = ENV.fetch("SEED_ADMIN_PASSWORD", "admin-password-123")
  learner_password = ENV.fetch("SEED_LEARNER_PASSWORD", "learner-password-123")

  admin = User.find_or_initialize_by(email: "admin@example.com")
  admin.assign_attributes(
    name: "Admin", role: :admin, experience_band: :staff,
    password: admin_password, password_confirmation: admin_password,
    confirmed_at: Time.current
  )
  admin.save!
  admin.create_streak! unless admin.streak

  learner = User.find_or_initialize_by(email: "learner@example.com")
  learner.assign_attributes(
    name: "Sam Learner", role: :learner, experience_band: :associate,
    password: learner_password, password_confirmation: learner_password,
    confirmed_at: Time.current
  )
  learner.save!
  learner.create_streak! unless learner.streak

  # Give the demo learner enough history that the dashboard, progress charts
  # and adaptive recommendations have something real to show.
  if learner.skill_progresses.empty?
    [
      [ "ruby-basics", { understanding: 88, prediction: 82, implementation: 79,
                         debugging: 71, explanation: 74, application: 68 } ],
      [ "ruby-collections", { understanding: 80, prediction: 74, implementation: 72,
                              debugging: 60, explanation: 62, application: 55 } ],
      [ "sql-joins", { understanding: 76, prediction: 58, implementation: 54,
                       debugging: 41, explanation: 49, application: 38 } ],
      [ "complexity", { understanding: 64, prediction: 48, implementation: 40,
                        debugging: 33, explanation: 44, application: 30 } ],
      [ "searching", { understanding: 52, prediction: 36, implementation: 31,
                       debugging: 22, explanation: 28, application: 20 } ]
    ].each do |slug, scores|
      skill = Skill.find_by!(slug: slug)
      progress = SkillProgress.find_or_create_by!(user: learner, skill: skill)
      scores.each { |dim, value| progress.public_send("#{dim}_score=", value) }
      progress.attempts_count = 12
      progress.correct_count = 8
      progress.last_practiced_at = rand(1..6).days.ago
      # Derive the level through the same rules the engine uses, so demo data
      # cannot disagree with the mastery logic.
      progress.mastery_level = Mastery::Recorder::MASTERY_THRESHOLDS.find do |_level, bar|
        progress.dimension_scores.values.min >= bar[:min_each] &&
          progress.composite_score >= bar[:composite]
      end&.first&.to_s || "untested"
      progress.save!
    end

    # A plausible XP history so the progress chart is not empty.
    29.downto(0) do |days_ago|
      next if days_ago.even? && days_ago > 10

      amount = [ 10, 20, 30, 50 ].sample
      learner.xp_transactions.create!(
        amount: amount,
        reason: "Practice session",
        created_at: days_ago.days.ago,
        idempotency_key: "seed-history-#{days_ago}"
      )
    end
    total = learner.xp_transactions.sum(:amount)
    learner.update_columns(xp_total: total,
                           level: Gamification::LevelCurve.level_for(total))

    learner.streak.update!(current_length: 6, longest_length: 11,
                           last_active_on: Date.current)

    # Something already due, so the revision queue demonstrates itself.
    if (challenge = Challenge.find_by(slug: "debug-binary-search"))
      ReviewSchedule.find_or_create_by!(
        user: learner, reviewable_type: "Challenge", reviewable_id: challenge.id
      ) do |schedule|
        schedule.skill = challenge.skill
        schedule.due_on = Date.current
        schedule.interval_index = 1
        schedule.lapses = 1
      end
    end

    Gamification::AchievementEngine.new(user: learner).call
  end

  puts "    admin@example.com / learner@example.com"
end
