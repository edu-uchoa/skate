class CreateTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :training_sessions do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :maneuver, null: false, foreign_key: true

      # Agendamento (compromisso privado / próxima sessão)
      t.date    :scheduled_on
      t.integer :period                          # morning / afternoon / night
      t.string  :location_name

      # Checklist de segurança
      t.boolean :gear_checked,  null: false, default: false
      t.boolean :ground_clear,  null: false, default: false
      t.boolean :space_safe,    null: false, default: false

      # Resultado
      t.integer :status,  null: false, default: 0  # scheduled -> ... -> analyzed
      t.integer :outcome                            # felt_safe / felt_afraid / could_not
      t.text    :notes
      t.boolean :queued_offline, null: false, default: false
      t.datetime :started_at
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :training_sessions, [ :user_id, :status ]
    add_index :training_sessions, :scheduled_on
  end
end
