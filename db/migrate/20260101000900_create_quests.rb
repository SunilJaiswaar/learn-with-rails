class CreateQuests < ActiveRecord::Migration[8.1]
  def change
    create_table :quest_templates do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text   :briefing, null: false         # the "production alert" framing (spec 51)
      t.string :alert_label
      t.integer :xp_reward, null: false, default: 350
      t.integer :difficulty, null: false, default: 1
      t.references :skill, foreign_key: true
      t.jsonb :step_specs, null: false, default: []
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :quest_templates, :slug, unique: true

    create_table :quests do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :quest_template, null: false, foreign_key: true
      t.date :scheduled_on, null: false
      t.integer :status, null: false, default: 0   # 0 open 1 completed 2 expired
      t.integer :xp_awarded, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
    end
    add_index :quests, %i[user_id scheduled_on], unique: true
    add_index :quests, %i[user_id status]

    create_table :quest_steps do |t|
      t.references :quest, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string  :label, null: false
      t.string  :kind, null: false, default: "action"
      t.string  :target_type
      t.bigint  :target_id
      t.boolean :completed, null: false, default: false
      t.datetime :completed_at
      t.timestamps
    end
    add_index :quest_steps, %i[quest_id position], unique: true
  end
end
