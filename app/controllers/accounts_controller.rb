# Cadastro (e-mail ou telefone + senha), tela "Minha conta" e logout.
class AccountsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  require_no_authentication only: %i[new create]

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_account_path, alert: "Muitas tentativas. Aguarde alguns minutos." }

  def new
    @user = User.new
  end

  def create
    @user = User.register(**account_params)

    if @user.persisted?
      start_session_for(@user)
      # Escolher "Mentor" não dá acesso de mentor: leva ao pedido, que um mentor aprova.
      if params[:account_type] == "mentor"
        redirect_to new_mentor_application_path, notice: "Conta criada! Agora complete seu pedido de mentor."
      else
        redirect_to install_path, notice: "Conta criada! Bora começar."
      end
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:base, "Esse contato já tem uma conta. Use \"Entrar\".")
    render :new, status: :unprocessable_entity
  end

  # Tela "Perfil" (aba de baixo): nível, XP, ofensiva, estilo, avatar, skate e a conta.
  def show
    @stats = ProfileStats.new(current_user)
    @look  = Avatar.new(current_user.avatar_options)
    @deck  = Deck.new(current_user.board_options)
    @tab   = params[:aba] == "skate" ? "skate" : "avatar"
  end

  def destroy
    sign_out
    redirect_to root_path, notice: "Sessão encerrada neste aparelho."
  end

  def destroy_all
    current_user.sign_out_everywhere!
    sign_out
    redirect_to root_path, notice: "Sessão encerrada em todos os aparelhos."
  end

  private

  def account_params
    params.require(:user).permit(:contact, :password, :password_confirmation)
          .to_h.symbolize_keys.with_defaults(contact: "", password: "", password_confirmation: "")
  end
end
