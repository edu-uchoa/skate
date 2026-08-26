class CreateDiagnosisBlockers < ActiveRecord::Migration[8.1]
  def change
    # Passo 2 do diagnóstico: pode marcar mais de um.
    create_table :diagnosis_blockers do |t|
      t.references :diagnosis, null: false, foreign_key: true
      t.integer :kind, null: false

      t.timestamps
    end

    add_index :diagnosis_blockers, [ :diagnosis_id, :kind ], unique: true
  end
end
