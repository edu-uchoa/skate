module Admin
  # Contas do app: buscar por nickname#0000 ou contato, tirar o acesso de mentor ou de
  # administrador e remover a conta com tudo dela (vídeos, progresso e chat).
  class UsersController < BaseController
    before_action :set_user, only: %i[destroy demote]
    before_action :protect_super_admin, only: %i[destroy demote]

    def index
      @query = params[:q].to_s.strip
      @users = User.registered.search(@query).order(created_at: :desc).limit(LIMIT)
      @video_counts = TrainingSession.joins(:clip_attachment).where(user_id: @users.map(&:id)).group(:user_id).count
    end

    def destroy
      label = @user.handle || @user.contact
      @user.destroy!
      audit("removeu a conta #{@user.id} (#{label})")
      redirect_to admin_users_path(q: params[:q].presence), notice: "Conta #{label} removida, com vídeos, progresso e chat."
    end

    def demote
      label = @user.handle || @user.contact
      if @user.role_learner?
        redirect_to admin_users_path(q: params[:q].presence), alert: "#{label} já é aprendiz."
      else
        role = @user.role
        @user.revoke_mentor! # volta a aprendiz e encerra as sessões abertas
        audit("tirou o acesso de #{role} da conta #{@user.id} (#{label})")
        redirect_to admin_users_path(q: params[:q].presence), notice: "#{label} voltou a ser aprendiz. As sessões dela foram encerradas."
      end
    end

    private

    def set_user
      @user = User.registered.find(params[:id])
    end

    # A conta de super administrador (a sua e qualquer outra da lista) não sai pelo painel.
    def protect_super_admin
      return unless @user.super_admin?
      redirect_to admin_users_path, alert: "A conta de super administrador não pode ser alterada pelo painel."
    end
  end
end
