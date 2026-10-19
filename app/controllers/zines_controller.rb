# Aba "Zine": todos os vídeos gravados/enviados pelo skatista, com o andamento
# da análise de cada um. Nada é copiado: a lista vem dos treinos com vídeo.
class ZinesController < ApplicationController
  # Mentor e administrador usam a Zine do mentor, com os vídeos dos aprendizes.
  before_action -> { redirect_to mentor_zine_path if current_user.mentor_access? }
  before_action :require_age_gate

  def show
    TrainingSession.purge_expired_clips! # vídeo que passou de 1 mês não aparece mais
    @training_sessions = current_user.training_sessions.with_clip.recent
    @analysis_running  = @training_sessions.any?(&:analysis_running?)
  end
end
