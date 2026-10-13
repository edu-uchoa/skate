# Chat entre cada aprendiz e a equipe de mentores (Conversation e Message): uma
# conversa por aprendiz, lida e respondida por todos os mentores.
class CreateConversationsAndMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :learner, null: false, foreign_key: { to_table: :users }, index: { unique: true }
      t.datetime :learner_message_at # última mensagem do aprendiz
      t.datetime :mentor_message_at  # última mensagem de um mentor
      t.datetime :learner_read_at
      t.datetime :mentors_read_at
      t.timestamps
    end

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      # Se a conta de um mentor for apagada, a mensagem fica, sem o autor.
      t.references :author, foreign_key: { to_table: :users, on_delete: :nullify }
      t.text :body, null: false
      t.timestamps
    end
  end
end
