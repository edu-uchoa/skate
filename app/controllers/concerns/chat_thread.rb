# O que o chat faz igual para o aprendiz (ChatsController) e para o mentor
# (Mentor::ChatsController): mostrar a conversa, entregar só as mensagens novas
# (o navegador pergunta a cada poucos segundos, chat_controller.js) e mandar uma.
module ChatThread
  extend ActiveSupport::Concern

  RECENT_MESSAGES = 200

  private

  # Página da conversa. Com ?depois=ID (turbo-stream), só as mensagens depois dessa;
  # sem nada novo, 204. Quem abre a conversa leu tudo o que estava lá.
  def render_thread(conversation)
    conversation&.read_by!(current_user)
    messages = conversation ? conversation.messages.includes(:author) : Message.none

    if request.format.turbo_stream?
      fresh = messages.where("messages.id > ?", params[:depois].to_i).to_a
      return head(:no_content) if fresh.empty?

      render turbo_stream: [ turbo_stream.remove("chat-empty"), *fresh.map { |message| append_message(message) } ]
    else
      @messages = messages.last(RECENT_MESSAGES)
    end
  end

  # Manda a mensagem e devolve o formulário limpo, ou com o erro e o texto digitado.
  def post_message(conversation, form_url:, back_to:)
    message = conversation.post!(current_user, params.require(:message).permit(:body)[:body])

    respond_to do |format|
      format.turbo_stream do
        if message.persisted?
          render turbo_stream: [ turbo_stream.remove("chat-empty"), append_message(message), chat_form(form_url, Message.new) ]
        else
          render turbo_stream: chat_form(form_url, message), status: :unprocessable_entity
        end
      end
      format.html { redirect_to back_to, alert: (message.errors.full_messages.to_sentence unless message.persisted?) }
    end
  end

  def append_message(message)
    turbo_stream.append("chat-messages", partial: "chats/message", locals: { message: message, viewer: current_user })
  end

  def chat_form(url, message) = turbo_stream.replace("chat-form", partial: "chats/form", locals: { url: url, message: message })
end
