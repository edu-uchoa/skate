# O aprendiz escolhe o mentor que avalia o vídeo e, na devolutiva, dá de 1 a 10
# rolamentos ao mentor (com uma mensagem opcional). O mentor escreve um resumo
# profissional, que aparece na hora da escolha.
class AddMentorChoiceAndRatings < ActiveRecord::Migration[8.1]
  def change
    # Mentor escolhido; se a conta dele for apagada, o vídeo volta para qualquer mentor.
    add_reference :training_sessions, :mentor, foreign_key: { to_table: :users, on_delete: :nullify }

    add_column :users, :mentor_bio, :text

    add_column :ai_reviews, :rating, :integer
    add_column :ai_reviews, :rating_comment, :text
    add_column :ai_reviews, :rated_at, :datetime
  end
end
