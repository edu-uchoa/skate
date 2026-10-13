# O mentor pode revisar uma devolutiva já enviada (aba "Todos" da Zine do mentor):
# revised_at guarda quando foi a última edição.
class AddRevisedAtToAiReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_reviews, :revised_at, :datetime
  end
end
