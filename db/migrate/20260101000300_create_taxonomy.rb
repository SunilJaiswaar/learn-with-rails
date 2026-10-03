class CreateTaxonomy < ActiveRecord::Migration[8.1]
  def change
    create_table :technologies do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category, null: false, default: "language"
      t.text   :summary
      t.string :icon
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :technologies, :slug, unique: true

    # Version-aware curriculum (spec 60): never present obsolete APIs as current.
    create_table :technology_versions do |t|
      t.references :technology, null: false, foreign_key: true
      t.string :number, null: false
      t.date   :released_on
      t.integer :status, null: false, default: 0        # 0 current, 1 maintained, 2 deprecated, 3 eol
      t.date   :deprecated_on
      t.string :docs_url
      t.text   :notes
      t.timestamps
    end
    add_index :technology_versions, %i[technology_id number], unique: true
    add_index :technology_versions, :status

    create_table :worlds do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text   :tagline
      t.text   :summary
      t.string :accent_color, null: false, default: "#6366f1"
      t.string :icon
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :worlds, :slug, unique: true

    create_table :skills do |t|
      t.references :world, foreign_key: true
      t.references :technology, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text   :summary
      t.integer :tier, null: false, default: 0          # depth in the tree
      t.integer :position, null: false, default: 0
      t.string :icon
      t.integer :grid_x, null: false, default: 0        # skill-tree layout
      t.integer :grid_y, null: false, default: 0
      t.timestamps
    end
    add_index :skills, :slug, unique: true
    add_index :skills, %i[world_id tier]

    # Directed acyclic prerequisite graph (spec 50).
    create_table :skill_dependencies do |t|
      t.references :skill, null: false, foreign_key: true
      t.references :prerequisite, null: false, foreign_key: { to_table: :skills }
      t.timestamps
    end
    add_index :skill_dependencies, %i[skill_id prerequisite_id], unique: true,
              name: "index_skill_deps_unique"
    add_check_constraint :skill_dependencies, "skill_id <> prerequisite_id",
                         name: "skill_deps_no_self_reference"

    create_table :learning_paths do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text   :summary
      t.string :audience
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :learning_paths, :slug, unique: true

    create_table :learning_path_steps do |t|
      t.references :learning_path, null: false, foreign_key: true
      t.references :skill, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string  :note
      t.timestamps
    end
    add_index :learning_path_steps, %i[learning_path_id skill_id], unique: true,
              name: "index_path_steps_unique"
    add_index :learning_path_steps, %i[learning_path_id position]
  end
end
