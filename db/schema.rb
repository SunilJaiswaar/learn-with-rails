# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_01_001200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "unaccent"

  create_table "achievements", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description", null: false
    t.string "icon", default: "trophy", null: false
    t.string "rule_key", null: false
    t.integer "threshold", default: 1, null: false
    t.integer "xp_reward", default: 50, null: false
    t.integer "tier", default: 0, null: false
    t.boolean "hidden", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rule_key"], name: "index_achievements_on_rule_key"
    t.index ["slug"], name: "index_achievements_on_slug", unique: true
  end

  create_table "algorithm_steps", force: :cascade do |t|
    t.bigint "algorithm_id", null: false
    t.integer "position", default: 0, null: false
    t.jsonb "state", default: {}, null: false
    t.text "narration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["algorithm_id", "position"], name: "index_algorithm_steps_on_algorithm_id_and_position", unique: true
    t.index ["algorithm_id"], name: "index_algorithm_steps_on_algorithm_id"
  end

  create_table "algorithms", force: :cascade do |t|
    t.bigint "skill_id"
    t.bigint "topic_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "category", default: "sorting", null: false
    t.text "idea"
    t.text "pseudocode"
    t.string "time_best"
    t.string "time_average"
    t.string "time_worst"
    t.string "space_complexity"
    t.boolean "stable"
    t.string "visualizer_kind", default: "array", null: false
    t.jsonb "visualizer_config", default: {}, null: false
    t.jsonb "tradeoffs", default: [], null: false
    t.text "production_note"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_algorithms_on_category"
    t.index ["skill_id"], name: "index_algorithms_on_skill_id"
    t.index ["slug"], name: "index_algorithms_on_slug", unique: true
    t.index ["topic_id"], name: "index_algorithms_on_topic_id"
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.jsonb "value", default: {}, null: false
    t.string "category", default: "branding", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_id", "created_at"], name: "index_audit_logs_on_actor_id_and_created_at"
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
  end

  create_table "boss_attempts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "boss_battle_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "current_stage", default: 0, null: false
    t.integer "score", default: 0, null: false
    t.jsonb "stage_results", default: [], null: false
    t.integer "xp_awarded", default: 0, null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["boss_battle_id"], name: "index_boss_attempts_on_boss_battle_id"
    t.index ["user_id", "boss_battle_id", "created_at"], name: "index_boss_attempts_on_user_boss_time"
    t.index ["user_id"], name: "index_boss_attempts_on_user_id"
  end

  create_table "boss_battles", force: :cascade do |t|
    t.bigint "skill_id"
    t.bigint "world_id"
    t.string "title", null: false
    t.string "slug", null: false
    t.text "scenario", null: false
    t.string "boss_name", null: false
    t.integer "difficulty", default: 3, null: false
    t.integer "xp_reward", default: 250, null: false
    t.jsonb "stages", default: [], null: false
    t.text "debrief"
    t.boolean "published", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id"], name: "index_boss_battles_on_skill_id"
    t.index ["slug"], name: "index_boss_battles_on_slug", unique: true
    t.index ["world_id"], name: "index_boss_battles_on_world_id"
  end

  create_table "challenge_attempts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "challenge_id", null: false
    t.text "submitted_code", null: false
    t.integer "status", default: 0, null: false
    t.integer "tests_passed", default: 0, null: false
    t.integer "tests_total", default: 0, null: false
    t.integer "runtime_ms"
    t.text "stdout"
    t.text "stderr"
    t.jsonb "results", default: {}, null: false
    t.jsonb "review", default: {}, null: false
    t.integer "xp_awarded", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_id"], name: "index_challenge_attempts_on_challenge_id"
    t.index ["status"], name: "index_challenge_attempts_on_status"
    t.index ["user_id", "challenge_id", "created_at"], name: "index_attempts_on_user_challenge_time"
    t.index ["user_id"], name: "index_challenge_attempts_on_user_id"
  end

  create_table "challenge_tests", force: :cascade do |t|
    t.bigint "challenge_id", null: false
    t.string "name", null: false
    t.text "call_expression"
    t.text "expected"
    t.text "setup_sql"
    t.boolean "hidden", default: false, null: false
    t.integer "weight", default: 1, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_id", "position"], name: "index_challenge_tests_on_challenge_id_and_position"
    t.index ["challenge_id"], name: "index_challenge_tests_on_challenge_id"
    t.check_constraint "weight > 0", name: "challenge_tests_weight_positive"
  end

  create_table "challenges", force: :cascade do |t|
    t.bigint "topic_id"
    t.bigint "skill_id"
    t.string "title", null: false
    t.string "slug", null: false
    t.integer "challenge_type", default: 0, null: false
    t.integer "language", default: 0, null: false
    t.integer "difficulty", default: 0, null: false
    t.text "prompt", null: false
    t.text "starter_code"
    t.text "reference_solution"
    t.text "explanation"
    t.jsonb "metadata", default: {}, null: false
    t.integer "xp_award", default: 30, null: false
    t.integer "time_limit_ms", default: 5000, null: false
    t.integer "memory_limit_mb", default: 512, null: false
    t.boolean "published", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_type"], name: "index_challenges_on_challenge_type"
    t.index ["skill_id", "difficulty"], name: "index_challenges_on_skill_id_and_difficulty"
    t.index ["skill_id"], name: "index_challenges_on_skill_id"
    t.index ["slug"], name: "index_challenges_on_slug", unique: true
    t.index ["topic_id"], name: "index_challenges_on_topic_id"
    t.check_constraint "memory_limit_mb >= 64 AND memory_limit_mb <= 2048", name: "challenges_memory_limit_range"
    t.check_constraint "time_limit_ms >= 100 AND time_limit_ms <= 30000", name: "challenges_time_limit_range"
  end

  create_table "curriculum_modules", force: :cascade do |t|
    t.bigint "world_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "summary"
    t.integer "position", default: 0, null: false
    t.boolean "published", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_curriculum_modules_on_slug", unique: true
    t.index ["world_id"], name: "index_curriculum_modules_on_world_id"
  end

  create_table "hint_reveals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "hint_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hint_id"], name: "index_hint_reveals_on_hint_id"
    t.index ["user_id", "hint_id"], name: "index_hint_reveals_on_user_id_and_hint_id", unique: true
    t.index ["user_id"], name: "index_hint_reveals_on_user_id"
  end

  create_table "hints", force: :cascade do |t|
    t.bigint "challenge_id", null: false
    t.integer "level", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.text "body", null: false
    t.integer "xp_penalty", default: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_id", "position"], name: "index_hints_on_challenge_id_and_position"
    t.index ["challenge_id"], name: "index_hints_on_challenge_id"
    t.check_constraint "xp_penalty >= 0", name: "hints_penalty_non_negative"
  end

  create_table "interview_answers", force: :cascade do |t|
    t.bigint "interview_question_id", null: false
    t.text "body"
    t.integer "score", default: 0, null: false
    t.jsonb "evaluation", default: {}, null: false
    t.integer "seconds_taken"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["interview_question_id"], name: "index_interview_answers_unique", unique: true
    t.check_constraint "score >= 0 AND score <= 100", name: "interview_answers_score_range"
  end

  create_table "interview_questions", force: :cascade do |t|
    t.bigint "interview_id", null: false
    t.bigint "interview_round_id"
    t.bigint "question_id", null: false
    t.bigint "question_follow_up_id"
    t.integer "position", default: 0, null: false
    t.datetime "asked_at"
    t.integer "time_limit_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["interview_id", "position"], name: "index_interview_questions_on_interview_id_and_position", unique: true
    t.index ["interview_id"], name: "index_interview_questions_on_interview_id"
    t.index ["interview_round_id"], name: "index_interview_questions_on_interview_round_id"
    t.index ["question_follow_up_id"], name: "index_interview_questions_on_question_follow_up_id"
    t.index ["question_id"], name: "index_interview_questions_on_question_id"
  end

  create_table "interview_rounds", force: :cascade do |t|
    t.bigint "interview_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.jsonb "scores", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["interview_id", "position"], name: "index_interview_rounds_on_interview_id_and_position", unique: true
    t.index ["interview_id"], name: "index_interview_rounds_on_interview_id"
  end

  create_table "interview_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "summary"
    t.integer "experience_band", default: 0, null: false
    t.string "company_type"
    t.jsonb "round_specs", default: [], null: false
    t.integer "question_count", default: 8, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_interview_templates_on_slug", unique: true
  end

  create_table "interviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "interview_template_id"
    t.integer "status", default: 0, null: false
    t.integer "pressure_mode", default: 0, null: false
    t.integer "experience_band", default: 0, null: false
    t.string "company_type"
    t.integer "current_position", default: 0, null: false
    t.jsonb "competency_scores", default: {}, null: false
    t.jsonb "feedback", default: {}, null: false
    t.integer "xp_awarded", default: 0, null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["interview_template_id"], name: "index_interviews_on_interview_template_id"
    t.index ["user_id", "status"], name: "index_interviews_on_user_id_and_status"
    t.index ["user_id"], name: "index_interviews_on_user_id"
  end

  create_table "learning_path_steps", force: :cascade do |t|
    t.bigint "learning_path_id", null: false
    t.bigint "skill_id", null: false
    t.integer "position", default: 0, null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["learning_path_id", "position"], name: "index_learning_path_steps_on_learning_path_id_and_position"
    t.index ["learning_path_id", "skill_id"], name: "index_path_steps_unique", unique: true
    t.index ["learning_path_id"], name: "index_learning_path_steps_on_learning_path_id"
    t.index ["skill_id"], name: "index_learning_path_steps_on_skill_id"
  end

  create_table "learning_paths", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "summary"
    t.string "audience"
    t.integer "position", default: 0, null: false
    t.boolean "published", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_learning_paths_on_slug", unique: true
  end

  create_table "lesson_blocks", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.integer "block_type", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.string "heading"
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["block_type"], name: "index_lesson_blocks_on_block_type"
    t.index ["lesson_id", "position"], name: "index_lesson_blocks_on_lesson_id_and_position"
    t.index ["lesson_id"], name: "index_lesson_blocks_on_lesson_id"
    t.index ["payload"], name: "index_lesson_blocks_on_payload", using: :gin
  end

  create_table "lessons", force: :cascade do |t|
    t.bigint "topic_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.integer "position", default: 0, null: false
    t.integer "estimated_minutes", default: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id", "position"], name: "index_lessons_on_topic_id_and_position"
    t.index ["topic_id", "slug"], name: "index_lessons_on_topic_id_and_slug", unique: true
    t.index ["topic_id"], name: "index_lessons_on_topic_id"
  end

  create_table "quest_steps", force: :cascade do |t|
    t.bigint "quest_id", null: false
    t.integer "position", default: 0, null: false
    t.string "label", null: false
    t.string "kind", default: "action", null: false
    t.string "target_type"
    t.bigint "target_id"
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quest_id", "position"], name: "index_quest_steps_on_quest_id_and_position", unique: true
    t.index ["quest_id"], name: "index_quest_steps_on_quest_id"
  end

  create_table "quest_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "briefing", null: false
    t.string "alert_label"
    t.integer "xp_reward", default: 350, null: false
    t.integer "difficulty", default: 1, null: false
    t.bigint "skill_id"
    t.jsonb "step_specs", default: [], null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id"], name: "index_quest_templates_on_skill_id"
    t.index ["slug"], name: "index_quest_templates_on_slug", unique: true
  end

  create_table "question_attempts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "question_id", null: false
    t.bigint "question_follow_up_id"
    t.text "response"
    t.boolean "correct", default: false, null: false
    t.integer "score", default: 0, null: false
    t.jsonb "evaluation", default: {}, null: false
    t.integer "xp_awarded", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_follow_up_id"], name: "index_question_attempts_on_question_follow_up_id"
    t.index ["question_id"], name: "index_question_attempts_on_question_id"
    t.index ["user_id", "question_id", "created_at"], name: "index_q_attempts_on_user_question_time"
    t.index ["user_id"], name: "index_question_attempts_on_user_id"
    t.check_constraint "score >= 0 AND score <= 100", name: "question_attempts_score_range"
  end

  create_table "question_follow_ups", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.bigint "parent_id"
    t.text "body", null: false
    t.integer "depth", default: 1, null: false
    t.integer "position", default: 0, null: false
    t.string "trigger_kind", default: "always", null: false
    t.jsonb "trigger_keywords", default: [], null: false
    t.jsonb "answer_key", default: {}, null: false
    t.text "model_answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_question_follow_ups_on_parent_id"
    t.index ["question_id", "position"], name: "index_question_follow_ups_on_question_id_and_position"
    t.index ["question_id"], name: "index_question_follow_ups_on_question_id"
    t.check_constraint "depth >= 1 AND depth <= 6", name: "follow_ups_depth_range"
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "topic_id"
    t.bigint "skill_id"
    t.string "question_type", default: "mcq", null: false
    t.text "body", null: false
    t.text "model_answer"
    t.text "explanation"
    t.text "common_mistakes"
    t.integer "difficulty", default: 0, null: false
    t.integer "experience_band", default: 0, null: false
    t.string "company_type"
    t.string "interview_type"
    t.jsonb "options", default: [], null: false
    t.jsonb "answer_key", default: {}, null: false
    t.jsonb "related_concepts", default: [], null: false
    t.integer "xp_award", default: 15, null: false
    t.boolean "published", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["answer_key"], name: "index_questions_on_answer_key", using: :gin
    t.index ["company_type"], name: "index_questions_on_company_type"
    t.index ["question_type"], name: "index_questions_on_question_type"
    t.index ["skill_id", "experience_band"], name: "index_questions_on_skill_id_and_experience_band"
    t.index ["skill_id"], name: "index_questions_on_skill_id"
    t.index ["topic_id"], name: "index_questions_on_topic_id"
  end

  create_table "quests", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "quest_template_id", null: false
    t.date "scheduled_on", null: false
    t.integer "status", default: 0, null: false
    t.integer "xp_awarded", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quest_template_id"], name: "index_quests_on_quest_template_id"
    t.index ["user_id", "scheduled_on"], name: "index_quests_on_user_id_and_scheduled_on", unique: true
    t.index ["user_id", "status"], name: "index_quests_on_user_id_and_status"
    t.index ["user_id"], name: "index_quests_on_user_id"
  end

  create_table "review_schedules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "reviewable_type", null: false
    t.bigint "reviewable_id", null: false
    t.bigint "skill_id"
    t.date "due_on", null: false
    t.integer "interval_index", default: 0, null: false
    t.integer "lapses", default: 0, null: false
    t.integer "successes", default: 0, null: false
    t.datetime "last_reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id"], name: "index_review_schedules_on_skill_id"
    t.index ["user_id", "due_on"], name: "index_review_schedules_on_user_id_and_due_on"
    t.index ["user_id", "reviewable_type", "reviewable_id"], name: "index_review_schedules_unique_target", unique: true
    t.index ["user_id"], name: "index_review_schedules_on_user_id"
    t.check_constraint "interval_index >= 0", name: "review_schedules_interval_non_negative"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "skill_dependencies", force: :cascade do |t|
    t.bigint "skill_id", null: false
    t.bigint "prerequisite_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prerequisite_id"], name: "index_skill_dependencies_on_prerequisite_id"
    t.index ["skill_id", "prerequisite_id"], name: "index_skill_deps_unique", unique: true
    t.index ["skill_id"], name: "index_skill_dependencies_on_skill_id"
    t.check_constraint "skill_id <> prerequisite_id", name: "skill_deps_no_self_reference"
  end

  create_table "skill_progresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "skill_id", null: false
    t.integer "understanding_score", default: 0, null: false
    t.integer "prediction_score", default: 0, null: false
    t.integer "implementation_score", default: 0, null: false
    t.integer "debugging_score", default: 0, null: false
    t.integer "explanation_score", default: 0, null: false
    t.integer "application_score", default: 0, null: false
    t.integer "mastery_level", default: 0, null: false
    t.integer "attempts_count", default: 0, null: false
    t.integer "correct_count", default: 0, null: false
    t.datetime "last_practiced_at"
    t.datetime "mastered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id"], name: "index_skill_progresses_on_skill_id"
    t.index ["user_id", "mastery_level"], name: "index_skill_progresses_on_user_id_and_mastery_level"
    t.index ["user_id", "skill_id"], name: "index_skill_progresses_on_user_id_and_skill_id", unique: true
    t.index ["user_id"], name: "index_skill_progresses_on_user_id"
    t.check_constraint "application_score >= 0 AND application_score <= 100", name: "skill_progresses_application_range"
    t.check_constraint "debugging_score >= 0 AND debugging_score <= 100", name: "skill_progresses_debugging_range"
    t.check_constraint "explanation_score >= 0 AND explanation_score <= 100", name: "skill_progresses_explanation_range"
    t.check_constraint "implementation_score >= 0 AND implementation_score <= 100", name: "skill_progresses_implementation_range"
    t.check_constraint "prediction_score >= 0 AND prediction_score <= 100", name: "skill_progresses_prediction_range"
    t.check_constraint "understanding_score >= 0 AND understanding_score <= 100", name: "skill_progresses_understanding_range"
  end

  create_table "skills", force: :cascade do |t|
    t.bigint "world_id"
    t.bigint "technology_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.text "summary"
    t.integer "tier", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.string "icon"
    t.integer "grid_x", default: 0, null: false
    t.integer "grid_y", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_skills_on_slug", unique: true
    t.index ["technology_id"], name: "index_skills_on_technology_id"
    t.index ["world_id", "tier"], name: "index_skills_on_world_id_and_tier"
    t.index ["world_id"], name: "index_skills_on_world_id"
  end

  create_table "streaks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "current_length", default: 0, null: false
    t.integer "longest_length", default: 0, null: false
    t.date "last_active_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_streaks_on_user_id", unique: true
  end

  create_table "technologies", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "category", default: "language", null: false
    t.text "summary"
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_technologies_on_slug", unique: true
  end

  create_table "technology_versions", force: :cascade do |t|
    t.bigint "technology_id", null: false
    t.string "number", null: false
    t.date "released_on"
    t.integer "status", default: 0, null: false
    t.date "deprecated_on"
    t.string "docs_url"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_technology_versions_on_status"
    t.index ["technology_id", "number"], name: "index_technology_versions_on_technology_id_and_number", unique: true
    t.index ["technology_id"], name: "index_technology_versions_on_technology_id"
  end

  create_table "topic_completions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "topic_id", null: false
    t.integer "blocks_seen", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id"], name: "index_topic_completions_on_topic_id"
    t.index ["user_id", "topic_id"], name: "index_topic_completions_on_user_id_and_topic_id", unique: true
    t.index ["user_id"], name: "index_topic_completions_on_user_id"
  end

  create_table "topics", force: :cascade do |t|
    t.bigint "curriculum_module_id", null: false
    t.bigint "skill_id"
    t.bigint "technology_version_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.text "hook", null: false
    t.text "summary"
    t.integer "position", default: 0, null: false
    t.integer "estimated_minutes", default: 5, null: false
    t.integer "difficulty", default: 0, null: false
    t.integer "xp_award", default: 10, null: false
    t.boolean "published", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["curriculum_module_id", "position"], name: "index_topics_on_curriculum_module_id_and_position"
    t.index ["curriculum_module_id"], name: "index_topics_on_curriculum_module_id"
    t.index ["skill_id"], name: "index_topics_on_skill_id"
    t.index ["slug"], name: "index_topics_on_slug", unique: true
    t.index ["technology_version_id"], name: "index_topics_on_technology_version_id"
    t.check_constraint "estimated_minutes >= 1 AND estimated_minutes <= 180", name: "topics_minutes_range"
  end

  create_table "user_achievements", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "achievement_id", null: false
    t.datetime "awarded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_id"], name: "index_user_achievements_on_achievement_id"
    t.index ["user_id", "achievement_id"], name: "index_user_achievements_on_user_id_and_achievement_id", unique: true
    t.index ["user_id"], name: "index_user_achievements_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.integer "role", default: 0, null: false
    t.integer "experience_band", default: 0, null: false
    t.string "timezone", default: "UTC", null: false
    t.string "theme", default: "dark", null: false
    t.boolean "reduced_motion", default: false, null: false
    t.integer "xp_total", default: 0, null: false
    t.integer "level", default: 1, null: false
    t.datetime "last_seen_at"
    t.datetime "confirmed_at"
    t.integer "failed_login_count", default: 0, null: false
    t.datetime "locked_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "char_length(email::text) >= 3 AND char_length(email::text) <= 255", name: "users_email_length"
    t.check_constraint "level >= 1", name: "users_level_min"
    t.check_constraint "xp_total >= 0", name: "users_xp_non_negative"
  end

  create_table "worlds", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "tagline"
    t.text "summary"
    t.string "accent_color", default: "#6366f1", null: false
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.boolean "published", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_worlds_on_slug", unique: true
  end

  create_table "xp_transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "amount", null: false
    t.string "reason", null: false
    t.string "source_type"
    t.bigint "source_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "idempotency_key"
    t.index ["source_type", "source_id"], name: "index_xp_transactions_on_source_type_and_source_id"
    t.index ["user_id", "created_at"], name: "index_xp_transactions_on_user_id_and_created_at"
    t.index ["user_id", "idempotency_key"], name: "index_xp_transactions_idempotency", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["user_id"], name: "index_xp_transactions_on_user_id"
  end

  add_foreign_key "algorithm_steps", "algorithms"
  add_foreign_key "algorithms", "skills"
  add_foreign_key "algorithms", "topics"
  add_foreign_key "audit_logs", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "boss_attempts", "boss_battles"
  add_foreign_key "boss_attempts", "users", on_delete: :cascade
  add_foreign_key "boss_battles", "skills"
  add_foreign_key "boss_battles", "worlds"
  add_foreign_key "challenge_attempts", "challenges"
  add_foreign_key "challenge_attempts", "users", on_delete: :cascade
  add_foreign_key "challenge_tests", "challenges"
  add_foreign_key "challenges", "skills"
  add_foreign_key "challenges", "topics"
  add_foreign_key "curriculum_modules", "worlds"
  add_foreign_key "hint_reveals", "hints"
  add_foreign_key "hint_reveals", "users", on_delete: :cascade
  add_foreign_key "hints", "challenges"
  add_foreign_key "interview_answers", "interview_questions"
  add_foreign_key "interview_questions", "interview_rounds"
  add_foreign_key "interview_questions", "interviews"
  add_foreign_key "interview_questions", "question_follow_ups"
  add_foreign_key "interview_questions", "questions"
  add_foreign_key "interview_rounds", "interviews"
  add_foreign_key "interviews", "interview_templates"
  add_foreign_key "interviews", "users", on_delete: :cascade
  add_foreign_key "learning_path_steps", "learning_paths"
  add_foreign_key "learning_path_steps", "skills"
  add_foreign_key "lesson_blocks", "lessons"
  add_foreign_key "lessons", "topics"
  add_foreign_key "quest_steps", "quests"
  add_foreign_key "quest_templates", "skills"
  add_foreign_key "question_attempts", "question_follow_ups"
  add_foreign_key "question_attempts", "questions"
  add_foreign_key "question_attempts", "users", on_delete: :cascade
  add_foreign_key "question_follow_ups", "question_follow_ups", column: "parent_id"
  add_foreign_key "question_follow_ups", "questions"
  add_foreign_key "questions", "skills"
  add_foreign_key "questions", "topics"
  add_foreign_key "quests", "quest_templates"
  add_foreign_key "quests", "users", on_delete: :cascade
  add_foreign_key "review_schedules", "skills"
  add_foreign_key "review_schedules", "users", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "skill_dependencies", "skills"
  add_foreign_key "skill_dependencies", "skills", column: "prerequisite_id"
  add_foreign_key "skill_progresses", "skills"
  add_foreign_key "skill_progresses", "users", on_delete: :cascade
  add_foreign_key "skills", "technologies"
  add_foreign_key "skills", "worlds"
  add_foreign_key "streaks", "users", on_delete: :cascade
  add_foreign_key "technology_versions", "technologies"
  add_foreign_key "topic_completions", "topics"
  add_foreign_key "topic_completions", "users", on_delete: :cascade
  add_foreign_key "topics", "curriculum_modules"
  add_foreign_key "topics", "skills"
  add_foreign_key "topics", "technology_versions"
  add_foreign_key "user_achievements", "achievements"
  add_foreign_key "user_achievements", "users", on_delete: :cascade
  add_foreign_key "xp_transactions", "users", on_delete: :cascade
end
