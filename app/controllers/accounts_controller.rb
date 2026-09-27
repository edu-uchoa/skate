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
      redirect_to install_path, notice: "Conta criada! Bora começar."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:base, "Esse contato já tem uma conta. Use \"Entrar\".")
    render :new, status: :unprocessable_entity
  end

  # Tela "Minha conta".
  def show; end

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
