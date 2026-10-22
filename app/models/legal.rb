# Dados dos textos da LGPD (Política de Privacidade e Termos de Uso). Ficam no código,
# e não em config/initializers, para o servidor pegar mudanças sem precisar reiniciar.
module Legal
  # Data da versão atual dos textos: mude junto com pages/privacy e pages/terms.
  UPDATED_ON = Date.new(2026, 10, 22)

  # Quem responde pelos dados (controlador) e o e-mail para pedidos de acesso,
  # correção e exclusão. Dá para trocar no servidor sem mexer no código.
  def self.controller = ENV.fetch("PRIVACY_CONTROLLER", "Caio Lyra")
  def self.email      = ENV.fetch("PRIVACY_EMAIL", "caiolyrapeixoto@gmail.com")
end
