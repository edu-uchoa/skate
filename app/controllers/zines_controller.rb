# Aba "Zine": todos os vídeos gravados/enviados pelo skatista, com o andamento
# da análise de cada um. Nada é copiado: a lista vem dos treinos com vídeo.
class ZinesController < ApplicationController
  before_action :require_age_gate

  def show
    @training_sessions = current_user.training_sessions.with_clip.recent
    @analysis_running  = @training_sessions.any?(&:analysis_running?)
  end
end
