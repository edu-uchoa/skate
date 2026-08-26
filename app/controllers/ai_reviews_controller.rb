# Tela de espera ("Processando seu diagnóstico...") e a devolutiva da IA.
class AiReviewsController < ApplicationController
  before_action :require_age_gate

  def show
    @training_session = current_user.training_sessions.find(params[:training_session_id])
    @ai_review = @training_session.ai_review
    redirect_to track_path, alert: "Esse treino não tem análise de vídeo." if @ai_review.blank?
  end
end
