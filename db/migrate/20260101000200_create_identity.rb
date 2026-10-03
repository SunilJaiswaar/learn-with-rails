class CreateIdentity < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.integer :role, null: false, default: 0           # 0 learner, 1 author, 2 admin
      t.integer :experience_band, null: false, default: 0
      t.string  :timezone, null: false, default: "UTC"
      t.string  :theme, null: false, default: "dark"
      t.boolean :reduced_motion, null: false, default: false
      t.integer :xp_total, null: false, default: 0
      t.integer :level, null: false, default: 1
      t.datetime :last_seen_at
      t.datetime :confirmed_at
      t.integer :failed_login_count, null: false, default: 0
      t.datetime :locked_until
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_check_constraint :users, "xp_total >= 0", name: "users_xp_non_negative"
    add_check_constraint :users, "level >= 1", name: "users_level_min"
    add_check_constraint :users, "char_length(email::text) BETWEEN 3 AND 255", name: "users_email_length"

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :sessions, :token_digest, unique: true
    add_index :sessions, :expires_at
  end
end
