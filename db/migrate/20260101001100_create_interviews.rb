class CreateInterviews < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_templates do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text   :summary
      t.integer :experience_band, null: false, default: 0
      t.string  :company_type
      t.jsonb   :round_specs, null: false, default: []   # ordered rounds -> skill/type filters
      t.integer :question_count, null: false, default: 8
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :interview_templates, :slug, unique: true

    create_table :interviews do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :interview_template, foreign_key: true
      t.integer :status, null: false, default: 0       # 0 in_progress 1 completed 2 abandoned
      t.integer :pressure_mode, null: false, default: 0 # spec 44
      t.integer :experience_band, null: false, default: 0
      t.string  :company_type
      t.integer :current_position, null: false, default: 0
      t.jsonb   :competency_scores, null: false, default: {}  # spec 45
      t.jsonb   :feedback, null: false, default: {}
      t.integer :xp_awarded, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :interviews, %i[user_id status]

    create_table :interview_rounds do |t|
      t.references :interview, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.jsonb  :scores, null: false, default: {}
      t.timestamps
    end
    add_index :interview_rounds, %i[interview_id position], unique: true

    create_table :interview_questions do |t|
      t.references :interview, null: false, foreign_key: true
      t.references :interview_round, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.references :question_follow_up, foreign_key: true
      t.integer :position, null: false, default: 0
      t.datetime :asked_at
      t.integer :time_limit_seconds
      t.timestamps
    end
    add_index :interview_questions, %i[interview_id position], unique: true

    create_table :interview_answers do |t|
      t.references :interview_question, null: false, foreign_key: true,
                   index: { unique: true, name: "index_interview_answers_unique" }
      t.text    :body
      t.integer :score, null: false, default: 0
      t.jsonb   :evaluation, null: false, default: {}
      t.integer :seconds_taken
      t.timestamps
    end
    add_check_constraint :interview_answers, "score BETWEEN 0 AND 100",
                         name: "interview_answers_score_range"
  end
end
