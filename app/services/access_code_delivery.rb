# Entrega do código de acesso.
#
# Em desenvolvimento apenas escreve no log. Em produção, plugue aqui o provedor
# de e-mail (ActionMailer) e o de WhatsApp (API do provedor escolhido).
class AccessCodeDelivery
  def initialize(access_code)
    @access_code = access_code
  end

  def call
    case access_code.channel
    when "email"    then deliver_email
    when "whatsapp" then deliver_whatsapp
    end
  end

  private

  attr_reader :access_code

  def deliver_email
    # TODO: AccessCodeMailer.with(access_code: access_code).code.deliver_later
    log
  end

  def deliver_whatsapp
    # TODO: chamada à API de mensagens.
    log
  end

  # Enquanto não há envio de verdade, o código só vai para o log em desenvolvimento. Em
  # produção, quem lê o log do servidor (Render) poderia usar o código para trocar a
  # senha de outra pessoa, inclusive de uma conta de administrador ou de mentor.
  def log
    if Rails.env.production?
      Rails.logger.warn("[FlipaAi] pedido de código de acesso: o envio por e-mail/WhatsApp ainda não existe (código não registrado)")
    else
      Rails.logger.info("[FlipaAi] código #{access_code.code} para #{access_code.destination}")
    end
  end
end
