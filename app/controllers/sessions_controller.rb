# "Entrar": login com e-mail ou telefone e senha.
class SessionsController < ApplicationController
  allow_unauthenticated_access
  require_no_authentication

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Muitas tentativas. Aguarde alguns minutos." }

  def new; end

  def create
    contact = params.dig(:session, :contact).to_s.strip

    if (user = User.authenticate_by_contact(contact, params.dig(:session, :password)))
      return_to = start_session_for(user)
      redirect_to return_to || track_path, notice: "Que bom te ver de volta!"
    else
      flash.now[:alert] = "E-mail/telefone ou senha incorretos."
      render :new, status: :unprocessable_entity
    end
  end
end
