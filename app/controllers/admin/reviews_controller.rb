module Admin
  # Devolutivas (os comentários dos mentores nos vídeos), da mais nova para a mais
  # antiga. Apagar tira o texto do aprendiz e devolve o vídeo para a fila do mentor.
  class ReviewsController < BaseController
    def index
      @reviews = AiReview.status_completed.includes(:reviewer, training_session: %i[user maneuver])
                         .order(completed_at: :desc).limit(LIMIT)
    end

    def destroy
      review = AiReview.status_completed.find(params[:id])
      review.retract!
      audit("apagou a devolutiva #{review.id} do treino #{review.training_session_id}")
      redirect_to admin_reviews_path, notice: "Devolutiva apagada. O vídeo voltou para a fila do mentor."
    end
  end
end
