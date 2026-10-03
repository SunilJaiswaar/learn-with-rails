class CreateBossBattles < ActiveRecord::Migration[8.1]
  def change
    create_table :boss_battles do |t|
      t.references :skill, foreign_key: true
      t.references :world, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text   :scenario, null: false
      t.string :boss_name, null: false
      t.integer :difficulty, null: false, default: 3
      t.integer :xp_reward, null: false, default: 250
      t.jsonb  :stages, null: false, default: []     # ordered multi-discipline stages
      t.text   :debrief
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :boss_battles, :slug, unique: true

    create_table :boss_attempts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :boss_battle, null: false, foreign_key: true
      t.integer :status, null: false, default: 0    # 0 in_progress 1 won 2 lost
      t.integer :current_stage, null: false, default: 0
      t.integer :score, null: false, default: 0
      t.jsonb   :stage_results, null: false, default: []
      t.integer :xp_awarded, null: false, default: 0
      t.datetime :finished_at
      t.timestamps
    end
    add_index :boss_attempts, %i[user_id boss_battle_id created_at],
              name: "index_boss_attempts_on_user_boss_time"
  end
end
