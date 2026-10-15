# Volta do "Entrar com o Google" (OmniAuth, config/initializers/omniauth.rb).
#
# Sem conta aberta: entra na conta da pessoa (ou cria uma), e quem ainda não tem
# nickname#0000 vai escolher. Com uma conta antiga aberta (login com senha), liga
# essa conta ao Google pelo Perfil, para não perder o histórico.
class GoogleSessionsController < ApplicationController
  allow_unauthenticated_access

  rate_limit to: 20, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Muitas tentativas. Aguarde alguns minutos." }

  def create
    auth = request.env["omniauth.auth"]
    return link_signed_in_account(auth) if signed_in?

    user = User.from_google(auth)
    if user.nil?
      redirect_to new_session_path, alert: "Não deu para entrar: a conta Google precisa ter o e-mail confirmado."
    elsif !user.can_sign_in?
      redirect_to new_session_path, alert: "Não deu para entrar com essa conta. Fale com o suporte."
    else
      return_to = start_session_for(user)
      redirect_to(user.handle ? (return_to || track_path) : edit_nickname_path, notice: "Bora! Você entrou com o Google.")
    end
  end

  # O Google não completou (a pessoa cancelou, ou o app não está configurado lá).
  def failure
    redirect_to new_session_path, alert: "Não deu para entrar com o Google. Tente de novo."
  end

  private

  def link_signed_in_account(auth)
    uid = auth&.uid.to_s
    if current_user.google?
      redirect_to my_account_path, notice: "Sua conta já está ligada ao Google."
    elsif uid.blank? || auth.info&.email.blank?
      redirect_to my_account_path, alert: "A conta Google precisa ter o e-mail confirmado."
    elsif User.exists?(google_uid: uid)
      redirect_to my_account_path, alert: "Essa conta Google já está ligada a outra conta do Stance."
    else
      current_user.link_google!(uid)
      start_session_for(current_user) # o token mudou: a sessão deste aparelho continua
      redirect_to(current_user.handle ? my_account_path : edit_nickname_path, notice: "Conta ligada ao Google! Daqui em diante, entre pelo Google.")
    end
  end
end
