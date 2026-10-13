# Mensagem do aprendiz para a equipe de mentores (a conversa nasce na primeira).
class MessagesController < ApplicationController
  include ChatThread

  before_action :require_age_gate
  before_action -> { redirect_to mentor_chats_path if current_user.mentor_access? }
  rate_limit to: 20, within: 1.minute, only: :create,
             with: -> { redirect_to chat_path, alert: "Muitas mensagens seguidas. Espere um pouco e mande de novo." }

  def create
    post_message(Conversation.for(current_user), form_url: chat_messages_path, back_to: chat_path)
  end
end
