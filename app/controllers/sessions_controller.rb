# "Entrar": login com e-mail ou telefone e senha.
class SessionsController < ApplicationController
  allow_unauthenticated_access
  require_no_authentication

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Muitas tentativas. Aguarde alguns minutos." }

  def new; end

  def create
    contact = params.dig(:session, :contact).to_s.strip

    user = User.authenticate_by_contact(contact, params.dig(:session, :password))
    if user&.access_allowed?
      return_to = start_session_for(user)
      redirect_to return_to || home_path_for(user), notice: "Que bom te ver de volta!"
    else
      # Fora da lista de acesso: só depois da senha certa, então não revela quem tem conta.
      Rails.logger.warn("[FlipaAi] login com senha recusado: not_invited (conta #{user.id}), IP #{request.remote_ip}") if user
      flash.now[:alert] = user ? AllowedEmail::NOT_INVITED : "E-mail/telefone ou senha incorretos."
      render :new, status: :unprocessable_entity
    end
  end
end
