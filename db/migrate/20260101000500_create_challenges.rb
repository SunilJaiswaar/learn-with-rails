class CreateChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :challenges do |t|
      t.references :topic, foreign_key: true
      t.references :skill, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :challenge_type, null: false, default: 0
      t.integer :language, null: false, default: 0        # 0 ruby, 1 sql
      t.integer :difficulty, null: false, default: 0
      t.text   :prompt, null: false
      t.text   :starter_code
      t.text   :reference_solution
      t.text   :explanation
      t.jsonb  :metadata, null: false, default: {}        # e.g. complexity targets
      t.integer :xp_award, null: false, default: 30
      t.integer :time_limit_ms, null: false, default: 5000
      t.integer :memory_limit_mb, null: false, default: 512
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :challenges, :slug, unique: true
    add_index :challenges, %i[skill_id difficulty]
    add_index :challenges, :challenge_type
    add_check_constraint :challenges, "time_limit_ms BETWEEN 100 AND 30000",
                         name: "challenges_time_limit_range"
    add_check_constraint :challenges, "memory_limit_mb BETWEEN 64 AND 2048",
                         name: "challenges_memory_limit_range"

    create_table :challenge_tests do |t|
      t.references :challenge, null: false, foreign_key: true
      t.string :name, null: false
      t.text   :call_expression                 # ruby: expression evaluated in sandbox
      t.text   :expected                        # serialised expected value
      t.text   :setup_sql                       # sql challenges: fixture
      t.boolean :hidden, null: false, default: false
      t.integer :weight, null: false, default: 1
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :challenge_tests, %i[challenge_id position]
    add_check_constraint :challenge_tests, "weight > 0", name: "challenge_tests_weight_positive"

    # Progressive hints (spec 55): never reveal the answer first.
    create_table :hints do |t|
      t.references :challenge, null: false, foreign_key: true
      t.integer :level, null: false, default: 0     # 0 nudge .. 5 full solution
      t.integer :position, null: false, default: 0
      t.text :body, null: false
      t.integer :xp_penalty, null: false, default: 2
      t.timestamps
    end
    add_index :hints, %i[challenge_id position]
    add_check_constraint :hints, "xp_penalty >= 0", name: "hints_penalty_non_negative"

    create_table :challenge_attempts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :challenge, null: false, foreign_key: true
      t.text :submitted_code, null: false
      t.integer :status, null: false, default: 0    # 0 pending 1 passed 2 failed 3 error 4 timeout 5 rejected
      t.integer :tests_passed, null: false, default: 0
      t.integer :tests_total, null: false, default: 0
      t.integer :runtime_ms
      t.text   :stdout
      t.text   :stderr
      t.jsonb  :results, null: false, default: {}
      t.jsonb  :review, null: false, default: {}    # automated code review findings
      t.integer :xp_awarded, null: false, default: 0
      t.timestamps
    end
    add_index :challenge_attempts, %i[user_id challenge_id created_at],
              name: "index_attempts_on_user_challenge_time"
    add_index :challenge_attempts, :status

    create_table :hint_reveals do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :hint, null: false, foreign_key: true
      t.timestamps
    end
    add_index :hint_reveals, %i[user_id hint_id], unique: true
  end
end
