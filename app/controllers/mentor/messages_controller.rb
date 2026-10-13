module Mentor
  # Mensagem de um mentor para um aprendiz (entra na conversa da equipe com ele).
  class MessagesController < BaseController
    include ChatThread

    rate_limit to: 30, within: 1.minute, only: :create,
               with: -> { redirect_to mentor_chats_path, alert: "Muitas mensagens seguidas. Espere um pouco e mande de novo." }

    def create
      learner = User.role_learner.find(params[:chat_id])
      post_message(Conversation.for(learner), form_url: mentor_chat_messages_path(learner), back_to: mentor_chat_path(learner))
    end
  end
end
