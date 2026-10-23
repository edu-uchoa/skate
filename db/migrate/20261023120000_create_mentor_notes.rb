# Observações da equipe de mentores sobre um aprendiz (o que treinar na próxima aula,
# o que ajuda a evoluir). Aparecem só para os mentores no app.
class CreateMentorNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :mentor_notes do |t|
      # Conta do aprendiz apagada: as observações vão junto.
      t.references :learner, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      # Conta do mentor apagada: a observação fica, sem o autor.
      t.references :author, foreign_key: { to_table: :users, on_delete: :nullify }
      t.text :body, null: false
      t.timestamps
    end
  end
end
