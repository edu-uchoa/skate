module Mentor
  # Base da área do mentor: exige login (padrão do app) e conta de mentor ou de
  # administrador. Para os demais responde 404, sem revelar que a área existe.
  # A navegação entre Na fila, Todos, Ofensivas e Chat fica no menu de baixo
  # (shared/_mentor_nav), com os números de MentorNavHelper.
  class BaseController < ApplicationController
    before_action :require_mentor_access

    private

    def require_mentor_access
      not_found unless current_user.mentor_access?
    end

    # Aprovar e remover mentores: só administrador.
    def require_admin
      not_found unless current_user.admin_access?
    end

    def not_found
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
    end

    # Vídeos dos aprendizes (vídeos de mentores e administradores ficam de fora).
    def learner_clips = TrainingSession.of_learners
  end
end
