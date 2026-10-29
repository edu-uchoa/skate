# Volta do "Entrar com o Google" (OmniAuth, config/initializers/omniauth.rb).
#
# Sem conta aberta: entra na conta da pessoa (ou cria uma), e quem ainda não tem
# nickname#0000 vai escolher. Com uma conta antiga aberta (login com senha), liga
# essa conta ao Google pelo Perfil, para não perder o histórico. Conta Google que
# entra pela primeira vez precisa ser @gmail.com (User.from_google). No app publicado,
# só entra quem está na lista de acesso do painel (AllowedEmail).
class GoogleSessionsController < ApplicationController
  allow_unauthenticated_access

  rate_limit to: 20, within: 3.minutes, only: :create,
             with: -> { redirect_to root_path, alert: "Muitas tentativas. Aguarde alguns minutos." }

  # Avisos quando o Google não deixa entrar (User::GoogleRefusal).
  REFUSALS = {
    unverified_email: "Não deu para entrar: a conta Google precisa ter o e-mail confirmado.",
    email_domain:     "Entre com uma conta Google @gmail.com. Contas de escola, de empresa ou com outro e-mail não são aceitas.",
    not_invited:      AllowedEmail::NOT_INVITED,
    other_google:     "Esse e-mail já está ligado a outra conta Google. Entre com a conta Google que você usou da primeira vez."
  }.freeze

  def create
    auth = request.env["omniauth.auth"]
    return link_signed_in_account(auth) if signed_in?

    user = User.from_google(auth)
    return redirect_to(root_path, alert: "Não deu para entrar com essa conta. Fale com o suporte.") unless user.can_sign_in?

    return_to = start_session_for(user)
    # Rastro: toda entrada de super admin fica no log (quem, quando e de onde).
    Rails.logger.warn("[FlipaAi] super admin #{user.id} entrou (IP #{request.remote_ip})") if user.super_admin?
    redirect_to(user.handle ? (return_to || home_path_for(user)) : edit_nickname_path, notice: "Bora! Você entrou com o Google.")
  rescue User::GoogleRefusal => refusal
    refuse(refusal)
  end

  # O Google não completou (a pessoa cancelou, ou o app não está configurado lá).
  def failure
    redirect_to root_path, alert: "Não deu para entrar com o Google. Tente de novo."
  end

  private

  def link_signed_in_account(auth)
    uid = auth&.uid.to_s
    if current_user.google?
      redirect_to my_account_path, notice: "Sua conta já está ligada ao Google."
    elsif uid.blank? || auth.info&.email.blank?
      redirect_to my_account_path, alert: "A conta Google precisa ter o e-mail confirmado."
    elsif !User.google_email_allowed?(auth.info.email)
      refuse(User::GoogleRefusal.new(:email_domain, current_user), back_to: my_account_path)
    elsif User.exists?(google_uid: uid)
      redirect_to my_account_path, alert: "Essa conta Google já está ligada a outra conta do FlipaAi."
    else
      current_user.link_google!(uid)
      start_session_for(current_user) # o token mudou: a sessão deste aparelho continua
      redirect_to(current_user.handle ? my_account_path : edit_nickname_path, notice: "Conta ligada ao Google! Daqui em diante, entre pelo Google.")
    end
  end

  # Rastro: toda recusa fica no log com o motivo, a conta envolvida e o IP (sem o e-mail).
  def refuse(refusal, back_to: root_path)
    account = " (conta #{refusal.account.id})" if refusal.account
    Rails.logger.warn("[FlipaAi] login Google recusado: #{refusal.reason}#{account}, IP #{request.remote_ip}")
    redirect_to back_to, alert: REFUSALS.fetch(refusal.reason)
  end
end
