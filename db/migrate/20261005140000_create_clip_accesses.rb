class CreateClipAccesses < ActiveRecord::Migration[8.1]
  def change
    # Registro de quem assistiu a vídeos de outras pessoas (mentores e administradores):
    # se um vídeo vazar, dá para saber quem teve acesso e quando.
    create_table :clip_accesses do |t|
      t.references :viewer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :training_session, null: false, foreign_key: { on_delete: :cascade }
      t.string :ip_address
      t.string :user_agent
      t.datetime :created_at, null: false
    end
    add_index :clip_accesses, :created_at
  end
end
