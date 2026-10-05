module Mentor
  # Pedidos de mentor e mentores ativos: só administrador aprova, recusa ou remove.
  # Aprovar libera o acesso aos vídeos de todos os aprendizes (inclusive menores),
  # então confira quem é a pessoa antes.
  class RequestsController < BaseController
    before_action :require_admin

    def index
      @requests = User.mentor_requests
      @mentors  = User.role_mentor.includes(:mentor_approved_by).order(:mentor_approved_at)
    end

    def update
      user = User.mentor_requests.find(params[:id])
      user.approve_mentor!(by: current_user)
      redirect_to mentor_requests_path, notice: "#{user.contact} agora é mentor."
    end

    def destroy
      user = User.mentor_requests.find(params[:id])
      user.reject_mentor!
      redirect_to mentor_requests_path, notice: "Pedido de #{user.contact} recusado."
    end
  end
end
