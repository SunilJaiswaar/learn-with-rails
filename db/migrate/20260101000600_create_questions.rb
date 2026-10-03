class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.references :topic, foreign_key: true
      t.references :skill, foreign_key: true
      t.string :question_type, null: false, default: "mcq"
      t.text   :body, null: false
      t.text   :model_answer
      t.text   :explanation
      t.text   :common_mistakes
      t.integer :difficulty, null: false, default: 0
      t.integer :experience_band, null: false, default: 0   # spec 41
      t.string  :company_type                                # spec 42 (pattern category)
      t.string  :interview_type
      t.jsonb   :options, null: false, default: []           # mcq choices
      t.jsonb   :answer_key, null: false, default: {}        # expected keywords / index
      t.jsonb   :related_concepts, null: false, default: []
      t.integer :xp_award, null: false, default: 15
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :questions, %i[skill_id experience_band]
    add_index :questions, :question_type
    add_index :questions, :company_type
    add_index :questions, :answer_key, using: :gin

    # Follow-up probing (spec 43): prevents memorised answers.
    create_table :question_follow_ups do |t|
      t.references :question, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :question_follow_ups }
      t.text   :body, null: false
      t.integer :depth, null: false, default: 1
      t.integer :position, null: false, default: 0
      t.string  :trigger_kind, null: false, default: "always"  # always | keyword | missing_keyword
      t.jsonb   :trigger_keywords, null: false, default: []
      t.jsonb   :answer_key, null: false, default: {}
      t.text    :model_answer
      t.timestamps
    end
    add_index :question_follow_ups, %i[question_id position]
    add_check_constraint :question_follow_ups, "depth BETWEEN 1 AND 6",
                         name: "follow_ups_depth_range"

    create_table :question_attempts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :question, null: false, foreign_key: true
      t.references :question_follow_up, foreign_key: true
      t.text    :response
      t.boolean :correct, null: false, default: false
      t.integer :score, null: false, default: 0        # 0..100
      t.jsonb   :evaluation, null: false, default: {}
      t.integer :xp_awarded, null: false, default: 0
      t.timestamps
    end
    add_index :question_attempts, %i[user_id question_id created_at],
              name: "index_q_attempts_on_user_question_time"
    add_check_constraint :question_attempts, "score BETWEEN 0 AND 100",
                         name: "question_attempts_score_range"
  end
end
