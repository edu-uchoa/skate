# Dados dos textos da LGPD (config/initializers/flipaai.rb): quem responde pelos dados,
# o e-mail para pedidos e a data da versão atual.
module LegalHelper
  def legal_controller = Rails.configuration.x.flipaai.privacy_controller
  def legal_email      = Rails.configuration.x.flipaai.privacy_email
  def legal_updated_on = Rails.configuration.x.flipaai.legal_updated_on.strftime("%d/%m/%Y")

  def legal_email_link(subject = "Privacidade no FlipaAi")
    mail_to legal_email, legal_email, subject: subject, class: "auth-link"
  end

  # Voltar: quem já entrou volta ao Perfil; quem não entrou, à tela da logo.
  def legal_back_path = signed_in? ? my_account_path : root_path
end
