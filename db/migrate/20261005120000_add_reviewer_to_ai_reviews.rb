class AddReviewerToAiReviews < ActiveRecord::Migration[8.1]
  def change
    # Mentor que escreveu a devolutiva (vazio quando vier de análise automática).
    add_reference :ai_reviews, :reviewer, foreign_key: { to_table: :users }
  end
end
