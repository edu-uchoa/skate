# Acesso à plataforma exige conta: entrar com o Google (ou, nas contas antigas, e-mail/telefone e senha).
#
# O usuário é identificado por um cookie assinado e permanente com o token da
# conta. Controllers públicos liberam ações com `allow_unauthenticated_access`.
module Authentication
  extend ActiveSupport::Concern

  COOKIE = :flipaai_token

  included do
    before_action :resume_session
    before_action :require_authentication
    helper_method :current_user, :signed_in?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    # Telas de cadastro/login não fazem sentido para quem já entrou.
    def require_no_authentication(**options)
      before_action :redirect_signed_in_user, **options
    end
  end

  private

  def resume_session
    Current.user = find_user
    Current.user.update_column(:last_seen_at, Time.current) if Current.user && stale_presence?
  end

  def find_user
    token = cookies.signed[COOKIE]
    return if token.blank?

    user = User.find_by(token: token)
    user if user&.can_sign_in?
  end

  def require_authentication
    return if signed_in?
    # HEAD é um GET sem corpo: tratar os dois igual (evita o alerta "HTTP verb confusion" do Brakeman).
    session[:return_to_after_authenticating] = request.fullpath if request.get? || request.head?
    redirect_to root_path, alert: "Entre com a sua conta Google para continuar."
  end

  def redirect_signed_in_user
    redirect_to track_path if signed_in?
  end

  # Troca de identidade: a sessão antiga é descartada (evita fixação de sessão).
  # Retorna a página que o usuário tentou abrir antes de entrar, se houver.
  def start_session_for(user)
    return_to = session[:return_to_after_authenticating]
    reset_session
    cookies.signed.permanent[COOKIE] = { value: user.token, httponly: true, same_site: :lax }
    Current.user = user
    return_to
  end

  def sign_out
    cookies.delete(COOKIE)
    reset_session
    Current.user = nil
  end

  def current_user = Current.user

  def signed_in? = current_user.present?

  def stale_presence?
    Current.user.last_seen_at.nil? || Current.user.last_seen_at < 1.hour.ago
  end

  # Bloqueia o app enquanto a porta de idade não for respondida. Quem entrou pelo
  # Google escolhe antes o nickname#0000 (é como aparece para os outros).
  def require_age_gate
    return redirect_to(edit_nickname_path) if current_user.google? && current_user.handle.nil?
    return if current_user.accepted_terms? && current_user.old_enough?
    redirect_to onboarding_age_gate_path
  end

  def require_diagnosis
    return if current_user.diagnosis&.completed?
    redirect_to onboarding_diagnosis_path
  end
end
