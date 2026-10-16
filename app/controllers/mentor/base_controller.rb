module Mentor
  # Base da área do mentor: exige login (padrão do app) e conta de mentor ou de
  # administrador. Para os demais responde 404, sem revelar que a área existe.
  class BaseController < ApplicationController
    before_action :require_mentor_access
    before_action :load_tab_counts

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
    def learner_clips = TrainingSession.with_clip.joins(:user).merge(User.role_learner)

    # Números das abas "Na fila", "Todos", "Ofensivas", "Chat" (conversas com mensagem
    # nova) e (para administrador) "Mentores".
    def load_tab_counts
      @justification_count = StreakJustification.for_review(current_user).count
      @video_count   = learner_clips.count
      @queue_count   = learner_clips.awaiting_review.count
      @chat_count    = Conversation.unread_by_mentors.count
      @request_count = User.mentor_requests.count if current_user.admin_access?
    end
  end
end
