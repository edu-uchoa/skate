# O aprendiz avalia o mentor na devolutiva: de 1 a 10 rolamentos e uma mensagem
# opcional. Uma vez por devolutiva; entra na média do mentor (MentorRating).
class ReviewRatingsController < ApplicationController
  before_action :require_age_gate

  def create
    @training_session = current_user.training_sessions.find(params[:training_session_id])
    @ai_review = @training_session.ai_review
    return redirect_to(track_path, alert: "Esse treino não tem devolutiva.") if @ai_review.blank?

    if @ai_review.rate(params.dig(:rating, :value), params.dig(:rating, :comment))
      redirect_to training_session_ai_review_path(@training_session, anchor: "avaliar"),
                  notice: "Avaliação enviada. Valeu! Ela já conta na média do mentor."
    else
      # Volta a devolutiva com o erro e o que foi escrito.
      @mentor_score = MentorRating.of(@ai_review.reviewer) if @ai_review.reviewer
      render "ai_reviews/show", status: :unprocessable_entity
    end
  end
end
