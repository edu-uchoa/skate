# Dados dos textos da LGPD (Legal): quem responde pelos dados, o e-mail para pedidos
# e a data da versão atual.
module LegalHelper
  def legal_controller = Legal.controller
  def legal_email      = Legal.email
  def legal_updated_on = Legal::UPDATED_ON.strftime("%d/%m/%Y")

  def legal_email_link(subject = "Privacidade no FlipaAi")
    mail_to legal_email, legal_email, subject: subject, class: "auth-link"
  end

  # Para onde o "Voltar" leva quando não há tela anterior no app (o back_link_controller
  # volta para a tela anterior quando há): quem ainda não aceitou os termos volta para a
  # tela de idade, onde estão os links; quem está no meio das perguntas, para elas; quem
  # já usa o app, ao Perfil; quem não entrou, à tela da logo.
  def legal_back_path
    return root_path unless signed_in?
    return onboarding_age_gate_path unless current_user.accepted_terms? || current_user.mentor_account?
    return onboarding_diagnosis_path unless current_user.onboarded? || current_user.mentor_account?
    my_account_path
  end
end
