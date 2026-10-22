# Menu de baixo da conta de mentor: Perfil, Todos, Na fila (o botão do meio, no lugar
# do Gravar), Ofensivas e Chat. Trilha, Picos e Gravar são só do aprendiz.
module MentorNavHelper
  # Conta de mentor sempre; o super admin (que também é aprendiz) quando está na área do mentor.
  def mentor_nav?
    return false unless signed_in?
    current_user.mentor_account? || (current_user.mentor_access? && controller_path.start_with?("mentor/"))
  end

  # Números dos ícones: vídeos esperando a devolutiva deste mentor, justificativas de
  # parada para avaliar, conversas com mensagem nova e (administrador) pedidos de mentor.
  def mentor_nav_counts
    @mentor_nav_counts ||= {
      queue:         TrainingSession.of_learners.awaiting_review.open_to(current_user).count,
      justifications: StreakJustification.for_review(current_user).count,
      chats:         Conversation.unread_by_mentors.count,
      requests:      (User.mentor_requests.count if current_user.admin_access?)
    }
  end

  # Qual ícone acende: "fila", "todos", "ofensivas", "chat", "perfil" ou nil.
  def mentor_nav_current
    case controller_path
    when "mentor/zines"                 then params[:aba] == "todos" ? "todos" : "fila"
    when "mentor/streak_justifications" then "ofensivas"
    when "mentor/chats", "mentor/messages" then "chat"
    when "accounts"                     then ("perfil" if action_name == "show")
    end
  end
end
