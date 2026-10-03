class CreateProgress < ActiveRecord::Migration[8.1]
  def change
    # Mastery is multi-dimensional evidence, never "I read it" (spec 48, 65).
    create_table :skill_progresses do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :skill, null: false, foreign_key: true
      t.integer :understanding_score, null: false, default: 0
      t.integer :prediction_score, null: false, default: 0
      t.integer :implementation_score, null: false, default: 0
      t.integer :debugging_score, null: false, default: 0
      t.integer :explanation_score, null: false, default: 0
      t.integer :application_score, null: false, default: 0
      t.integer :mastery_level, null: false, default: 0   # 0 untested 1 weak 2 developing 3 strong 4 mastered
      t.integer :attempts_count, null: false, default: 0
      t.integer :correct_count, null: false, default: 0
      t.datetime :last_practiced_at
      t.datetime :mastered_at
      t.timestamps
    end
    add_index :skill_progresses, %i[user_id skill_id], unique: true
    add_index :skill_progresses, %i[user_id mastery_level]
    %w[understanding prediction implementation debugging explanation application].each do |dim|
      add_check_constraint :skill_progresses, "#{dim}_score BETWEEN 0 AND 100",
                           name: "skill_progresses_#{dim}_range"
    end

    create_table :xp_transactions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :amount, null: false
      t.string  :reason, null: false
      t.string  :source_type
      t.bigint  :source_id
      t.jsonb   :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :xp_transactions, %i[user_id created_at]
    add_index :xp_transactions, %i[source_type source_id]
    # An idempotency key stops double-awarding the same accomplishment.
    t_idem = "index_xp_transactions_idempotency"
    add_column :xp_transactions, :idempotency_key, :string
    add_index :xp_transactions, %i[user_id idempotency_key], unique: true,
              where: "idempotency_key IS NOT NULL", name: t_idem

    create_table :achievements do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text   :description, null: false
      t.string :icon, null: false, default: "trophy"
      t.string :rule_key, null: false
      t.integer :threshold, null: false, default: 1
      t.integer :xp_reward, null: false, default: 50
      t.integer :tier, null: false, default: 0       # bronze/silver/gold
      t.boolean :hidden, null: false, default: false
      t.timestamps
    end
    add_index :achievements, :slug, unique: true
    add_index :achievements, :rule_key

    create_table :user_achievements do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :achievement, null: false, foreign_key: true
      t.datetime :awarded_at, null: false
      t.timestamps
    end
    add_index :user_achievements, %i[user_id achievement_id], unique: true

    create_table :streaks do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade },
                   index: { unique: true }
      t.integer :current_length, null: false, default: 0
      t.integer :longest_length, null: false, default: 0
      t.date    :last_active_on
      t.timestamps
    end

    # Spaced repetition (spec 47): wrong concepts come back automatically.
    create_table :review_schedules do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string  :reviewable_type, null: false
      t.bigint  :reviewable_id, null: false
      t.references :skill, foreign_key: true
      t.date    :due_on, null: false
      t.integer :interval_index, null: false, default: 0   # indexes into the interval ladder
      t.integer :lapses, null: false, default: 0
      t.integer :successes, null: false, default: 0
      t.datetime :last_reviewed_at
      t.timestamps
    end
    add_index :review_schedules, %i[user_id due_on]
    add_index :review_schedules, %i[user_id reviewable_type reviewable_id], unique: true,
              name: "index_review_schedules_unique_target"
    add_check_constraint :review_schedules, "interval_index >= 0",
                         name: "review_schedules_interval_non_negative"
  end
end
