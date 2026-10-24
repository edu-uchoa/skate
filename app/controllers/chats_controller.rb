# Chat do aprendiz com a equipe de mentores (os mentores usam Mentor::ChatsController).
class ChatsController < ApplicationController
  include ChatThread

  before_action :require_onboarding
  before_action -> { redirect_to mentor_chats_path if current_user.mentor_access? }

  def show
    render_thread(current_user.conversation)
  end
end
