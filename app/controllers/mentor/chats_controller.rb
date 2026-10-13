module Mentor
  # Chat com os aprendizes: a lista (quem mandou mensagem por último primeiro) e a
  # conversa com cada um. A conversa é da equipe: todos os mentores e
  # administradores veem e respondem as mesmas mensagens.
  class ChatsController < BaseController
    include ChatThread

    def index
      learners = User.role_learner.registered.includes(:conversation, :diagnosis).to_a
      @learners = learners.sort_by do |learner|
        last = learner.conversation&.last_message_at
        [ last ? 0 : 1, -(last || learner.registered_at).to_f ]
      end
      conversation_ids = learners.filter_map { |learner| learner.conversation&.id }
      @last_messages = Message.where(id: Message.where(conversation_id: conversation_ids).group(:conversation_id).select("MAX(id)"))
                              .index_by(&:conversation_id)
    end

    def show
      @learner = learner
      render_thread(@learner.conversation)
    end

    private

    # Só contas de aprendiz (mentor não abre chat com outro mentor).
    def learner = User.role_learner.find(params[:id])
  end
end
