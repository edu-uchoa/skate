# Lista de acesso do app publicado (config.x.flipaai.invite_only): só entra quem tem o
# e-mail aqui, e o super admin. O super admin inclui e tira pelo painel (/painel/acesso).
# Tirar daqui corta o acesso na hora, mas a conta e os dados continuam; apagar a conta
# tira o e-mail daqui junto (User).
#
# A lista de "Usuários de teste" do Google não serve para isso: o app pede só o e-mail
# (openid email) e, para esse login, o Google deixa entrar qualquer conta.
class AllowedEmail < ApplicationRecord
  # O aviso para quem não está na lista (login pelo Google ou com senha).
  NOT_INVITED = "O FlipaAi está em fase de testes, só para convidados. Peça para a equipe liberar o seu e-mail.".freeze

  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }

  validate :valid_google_email

  private

  # Mensagens inteiras em :base: aparecem assim no painel (shared/errors).
  def valid_google_email
    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      errors.add(:base, "Escreva um e-mail completo, como nome@gmail.com.")
    elsif !User.google_email_allowed?(email)
      errors.add(:base, "Só e-mails @gmail.com: o app só aceita conta Google @gmail.com.")
    elsif self.class.where.not(id: id).exists?(email: email)
      errors.add(:base, "#{email} já está na lista.")
    end
  end
end
