class CreateSkateSessionsAndStreakJustifications < ActiveRecord::Migration[8.1]
  def change
    # Vídeo gravado no horário de um rolê marcado no mapa: a prova de que a pessoa andou.
    add_column :training_sessions, :recorded_at_meetup, :boolean, default: false, null: false

    # Sessões de skate da ofensiva. Guardam só o dia: o lugar do rolê é apagado
    # quando ele acaba. validated_at = devolutiva do mentor (antes disso, já conta).
    create_table :skate_sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :training_session, foreign_key: { on_delete: :nullify }, index: { unique: true }
      t.date :skated_on, null: false
      t.datetime :validated_at
      t.timestamps
    end
    add_index :skate_sessions, %i[user_id skated_on]

    # Justificativas de parada da ofensiva, avaliadas por um mentor.
    create_table :streak_justifications do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.text :reason, null: false
      t.integer :status, null: false, default: 0
      t.references :reviewer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :reviewed_at
      t.timestamps
    end
  end
end
