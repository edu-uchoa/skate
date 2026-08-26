class CreateComebacks < ActiveRecord::Migration[8.1]
  def change
    # Rampa de retorno: registra o motivo da pausa para suavizar a volta.
    create_table :comebacks do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :reason, null: false   # injury / lost_focus / no_time
      t.integer :days_away

      t.timestamps
    end
  end
end
