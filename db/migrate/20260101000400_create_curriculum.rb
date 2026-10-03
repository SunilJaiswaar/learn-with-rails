class CreateCurriculum < ActiveRecord::Migration[8.1]
  def change
    create_table :curriculum_modules do |t|
      t.references :world, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text   :summary
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :curriculum_modules, :slug, unique: true

    # A topic is one micro-learning mission (spec 5): 2-10 minutes of work.
    create_table :topics do |t|
      t.references :curriculum_module, null: false, foreign_key: true
      t.references :skill, foreign_key: true
      t.references :technology_version, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text   :hook, null: false                 # the problem that creates curiosity
      t.text   :summary
      t.integer :position, null: false, default: 0
      t.integer :estimated_minutes, null: false, default: 5
      t.integer :difficulty, null: false, default: 0
      t.integer :xp_award, null: false, default: 10
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :topics, :slug, unique: true
    add_index :topics, %i[curriculum_module_id position]
    add_check_constraint :topics, "estimated_minutes BETWEEN 1 AND 180",
                         name: "topics_minutes_range"

    create_table :lessons do |t|
      t.references :topic, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :position, null: false, default: 0
      t.integer :estimated_minutes, null: false, default: 4
      t.timestamps
    end
    add_index :lessons, %i[topic_id slug], unique: true
    add_index :lessons, %i[topic_id position]

    # Lesson content is a sequence of typed, mostly-interactive blocks.
    # Prose is deliberately only one of many block types (spec 4: zero boring content).
    create_table :lesson_blocks do |t|
      t.references :lesson, null: false, foreign_key: true
      t.integer :block_type, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.string  :heading
      t.jsonb   :payload, null: false, default: {}
      t.timestamps
    end
    add_index :lesson_blocks, %i[lesson_id position]
    add_index :lesson_blocks, :block_type
    add_index :lesson_blocks, :payload, using: :gin

    create_table :topic_completions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :topic, null: false, foreign_key: true
      t.integer :blocks_seen, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
    end
    add_index :topic_completions, %i[user_id topic_id], unique: true
  end
end
