require "test_helper"

# Código de recuperação de senha: sem envio de verdade, ele só vai para o log em
# desenvolvimento. Em produção, quem lê o log do servidor trocaria a senha de outra
# pessoa (inclusive de um administrador).
class AccessCodeDeliveryTest < ActiveSupport::TestCase
  def logged_with_env(env)
    user = User.register(contact: "antiga@example.com", password: "manobra123", password_confirmation: "manobra123")
    code = AccessCode.issue!(user: user, destination: "antiga@example.com")
    logs = StringIO.new
    original_logger, original_env = Rails.logger, Rails.env
    Rails.logger = ActiveSupport::Logger.new(logs)
    Rails.env = env
    AccessCodeDelivery.new(code).call
    [ logs.string, code.code ]
  ensure
    Rails.logger = original_logger
    Rails.env = original_env
  end

  test "em produção, nem o código nem o contato vão para o log" do
    log, code = logged_with_env("production")
    assert_not_includes log, code
    assert_not_includes log, "antiga@example.com"
    assert_match "código não registrado", log
  end

  test "em desenvolvimento, o código aparece no log para testar" do
    log, code = logged_with_env("development")
    assert_includes log, code
  end
end
