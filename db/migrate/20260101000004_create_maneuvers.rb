class CreateManeuvers < ActiveRecord::Migration[8.1]
  def change
    # Cada "nó" da trilha: um drill, uma manobra ou uma avaliação.
    create_table :maneuvers do |t|
      t.references :learning_module, null: false, foreign_key: true
      t.string  :code,        null: false        # "1.2", "3.2"
      t.string  :slug,        null: false        # "empurrar"
      t.string  :name,        null: false        # "EMPURRAR"
      t.text    :description
      t.text    :why_now                          # bloco "Por que agora?"
      t.integer :kind,        null: false, default: 0  # drill / maneuver / assessment
      t.integer :difficulty,  null: false, default: 0  # beginner / intermediate / advanced
      t.string  :average_time                     # "2-3 semanas"
      t.string  :video_url
      t.integer :position,    null: false, default: 0
      t.boolean :requires_clip, null: false, default: false
      t.references :prerequisite, foreign_key: { to_table: :maneuvers }

      t.timestamps
    end

    add_index :maneuvers, :code, unique: true
    add_index :maneuvers, :slug, unique: true
  end
end
