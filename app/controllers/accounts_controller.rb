# "Salvar meu progresso": pede e-mail ou WhatsApp e dispara o código.
class AccountsController < ApplicationController
  def new
    redirect_to track_path if current_user.registered?
  end

  def create
    destination = params.dig(:account, :destination).to_s.strip

    if destination.blank?
      flash.now[:alert] = "Informe um e-mail ou telefone."
      return render :new, status: :unprocessable_entity
    end

    access_code = AccessCode.issue!(user: current_user, destination: destination)
    AccessCodeDelivery.new(access_code).call

    redirect_to new_access_code_path
  end

  def destroy
    sign_out
    redirect_to root_path, notice: "Sessão encerrada neste aparelho."
  end
end
