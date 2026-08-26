# Perfil temporário por padrão: ninguém precisa de conta para começar.
#
# O usuário é identificado por um cookie assinado e permanente. Ao salvar o
# progresso (código de acesso), o mesmo registro apenas ganha e-mail/telefone —
# nada é migrado, nada é perdido.
module Authentication
  extend ActiveSupport::Concern

  COOKIE = :sakte_token

  included do
    before_action :set_current_user
    helper_method :current_user, :anonymous_profile?
  end

  private

  def set_current_user
    Current.user = find_user || create_anonymous_user
    Current.user.update_column(:last_seen_at, Time.current) if stale_presence?
  end

  def find_user
    token = cookies.signed[COOKIE]
    token.present? ? User.find_by(token: token) : nil
  end

  def create_anonymous_user
    User.create!.tap { |user| sign_in(user) }
  end

  def sign_in(user)
    cookies.signed.permanent[COOKIE] = { value: user.token, httponly: true, same_site: :lax }
    Current.user = user
  end

  def sign_out
    cookies.delete(COOKIE)
    Current.user = nil
  end

  def current_user = Current.user

  def anonymous_profile? = current_user&.anonymous?

  def stale_presence?
    Current.user.last_seen_at.nil? || Current.user.last_seen_at < 1.hour.ago
  end

  # Bloqueia o app enquanto a porta de idade não for respondida.
  def require_age_gate
    return if current_user.accepted_terms? && current_user.old_enough?
    redirect_to onboarding_age_gate_path
  end

  def require_diagnosis
    return if current_user.diagnosis&.completed?
    redirect_to onboarding_diagnosis_path
  end
end
