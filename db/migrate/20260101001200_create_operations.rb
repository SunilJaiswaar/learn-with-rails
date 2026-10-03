class CreateOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.jsonb  :metadata, null: false, default: {}
      t.string :ip_address
      t.timestamps
    end
    add_index :audit_logs, %i[auditable_type auditable_id]
    add_index :audit_logs, %i[actor_id created_at]
    add_index :audit_logs, :action

    # Branding and tunables are editable from the admin panel (spec: configurable branding).
    create_table :app_settings do |t|
      t.string :key, null: false
      t.jsonb  :value, null: false, default: {}
      t.string :category, null: false, default: "branding"
      t.text   :description
      t.timestamps
    end
    add_index :app_settings, :key, unique: true
  end
end
