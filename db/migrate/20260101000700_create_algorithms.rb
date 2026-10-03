class CreateAlgorithms < ActiveRecord::Migration[8.1]
  def change
    create_table :algorithms do |t|
      t.references :skill, foreign_key: true
      t.references :topic, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category, null: false, default: "sorting"
      t.text   :idea
      t.text   :pseudocode
      t.string :time_best
      t.string :time_average
      t.string :time_worst
      t.string :space_complexity
      t.boolean :stable
      t.string  :visualizer_kind, null: false, default: "array"  # array | graph | dp_table | stack
      t.jsonb   :visualizer_config, null: false, default: {}
      t.jsonb   :tradeoffs, null: false, default: []
      t.text    :production_note
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :algorithms, :slug, unique: true
    add_index :algorithms, :category

    # Curated traces for the step-through visualiser (spec 7).
    create_table :algorithm_steps do |t|
      t.references :algorithm, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.jsonb   :state, null: false, default: {}
      t.text    :narration
      t.timestamps
    end
    add_index :algorithm_steps, %i[algorithm_id position], unique: true
  end
end
