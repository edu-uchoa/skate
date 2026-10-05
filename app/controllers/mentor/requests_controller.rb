module Mentor
  # Pedidos de mentor: quem já é mentor aprova ou recusa. Aprovar libera o acesso
  # aos vídeos de todos os aprendizes, então confira quem é a pessoa antes.
  class RequestsController < BaseController
    def index
      @requests = User.mentor_requests
    end

    def update
      user = User.mentor_requests.find(params[:id])
      user.approve_mentor!
      redirect_to mentor_requests_path, notice: "#{user.contact} agora é mentor."
    end

    def destroy
      user = User.mentor_requests.find(params[:id])
      user.reject_mentor!
      redirect_to mentor_requests_path, notice: "Pedido de #{user.contact} recusado."
    end
  end
end
