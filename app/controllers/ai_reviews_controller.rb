# Tela de espera ("na fila do mentor") e a devolutiva do vídeo do treino.
class AiReviewsController < ApplicationController
  before_action :require_onboarding

  def show
    @training_session = current_user.training_sessions.find(params[:training_session_id])
    @ai_review = @training_session.ai_review
    return redirect_to(track_path, alert: "Esse treino não tem análise de vídeo.") if @ai_review.blank?

    @ai_review.mark_seen! # o aprendiz viu a devolutiva: some o número do ícone Zine
    @mentor_score = MentorRating.of(@ai_review.reviewer) if @ai_review.reviewer
  end
end
