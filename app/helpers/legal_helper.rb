# Dados dos textos da LGPD (Legal): quem responde pelos dados, o e-mail para pedidos
# e a data da versão atual.
module LegalHelper
  def legal_controller = Legal.controller
  def legal_email      = Legal.email
  def legal_updated_on = Legal::UPDATED_ON.strftime("%d/%m/%Y")

  def legal_email_link(subject = "Privacidade no FlipaAi")
    mail_to legal_email, legal_email, subject: subject, class: "auth-link"
  end

  # Voltar: quem já entrou volta ao Perfil; quem não entrou, à tela da logo.
  def legal_back_path = signed_in? ? my_account_path : root_path
end
