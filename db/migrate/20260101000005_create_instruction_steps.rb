class CreateInstructionSteps < ActiveRecord::Migration[8.1]
  def change
    # Os passos numerados "01 / 02 / 03" da tela de drill.
    create_table :instruction_steps do |t|
      t.references :maneuver, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.text    :body,     null: false

      t.timestamps
    end

    add_index :instruction_steps, [ :maneuver_id, :position ]
  end
end
