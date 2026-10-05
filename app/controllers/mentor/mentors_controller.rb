module Mentor
  # Remover um mentor: só administrador. O acesso aos vídeos acaba na hora e as
  # sessões abertas da pessoa são encerradas em todos os aparelhos.
  class MentorsController < BaseController
    before_action :require_admin

    def destroy
      user = User.role_mentor.find(params[:id])
      user.revoke_mentor!
      redirect_to mentor_requests_path, notice: "#{user.contact} não é mais mentor."
    end
  end
end
