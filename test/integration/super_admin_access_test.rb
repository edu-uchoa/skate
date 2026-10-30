require "test_helper"
require "rake"

# Ninguém vira super admin pelo app: só com a concessão assinada na máquina do dono.
class SuperAdminAccessTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  test "conta antiga com o e-mail do dono + o Google de outra pessoa não vira super admin" do
    grant_super_admin("google-dono@example.com") # a conta Google do dono
    legacy = User.register(contact: "dono@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    legacy.update!(birth_year: 1990, terms_accepted_at: Time.current)

    # Quem souber (ou recuperar) a senha da conta antiga liga o Google DELE nela.
    post session_path, params: { session: { contact: "dono@example.com", password: PASSWORD } }
    sign_in_with_google("intruso@example.com")
    legacy.reload
    assert_equal "google-intruso@example.com", legacy.google_uid
    assert_equal "dono@example.com", legacy.email, "o e-mail continua o do dono"

    assert_not legacy.super_admin?, "antes, o e-mail na lista bastava"
    get admin_root_path
    assert_response :not_found
  end

  test "a conta Google autorizada entra no painel e a entrada fica no log" do
    grant_super_admin("google-dono@example.com")
    logs = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logs)
    sign_up_with_google("dono@example.com", nickname: "dono")
    Rails.logger = original_logger

    get admin_root_path
    assert_response :success
    assert_match(/super admin \d+ entrou/, logs.string)
  ensure
    Rails.logger = original_logger if original_logger
  end

  test "a sessão do super admin acaba em 12 horas, mesmo com uma cópia do cookie" do
    grant_super_admin("google-dono@example.com")
    sign_up_with_google("dono@example.com", nickname: "dono")
    copied_cookie = cookies[Authentication::COOKIE.to_s]

    travel Authentication::SUPER_ADMIN_SESSION - 1.minute
    get admin_root_path
    assert_response :success

    travel 2.minutes
    cookies[Authentication::COOKIE.to_s] = copied_cookie
    get admin_root_path
    assert_redirected_to root_path
  end

  test "quem não é super admin continua logado até sair" do
    grant_super_admin("google-dono@example.com")
    complete_onboarding(sign_up_with_google("aluna@example.com", nickname: "aluna"))

    travel 90.days
    get my_account_path
    assert_response :success
  end

  test "o painel mostra o código Google de cada conta, para o dono conceder da máquina dele" do
    grant_super_admin("google-dono@example.com")
    sign_up_with_google("aluna@example.com", nickname: "aluna")
    delete sign_out_path
    sign_up_with_google("dono@example.com", nickname: "dono")

    get admin_users_path
    assert_select ".admin-user code", "google-aluna@example.com"
  end

  test "super_admin:conceder gera, na máquina do dono, a concessão que o app aceita" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("super_admin:conceder")
    owner = sign_up_with_google("dono@example.com", nickname: "dono")

    Dir.mktmpdir do |home|
      key = OpenSSL::PKey.generate_key("ED25519")
      FileUtils.mkdir_p(File.join(home, ".flipaai"))
      File.write(File.join(home, ".flipaai", "super_admin_ed25519.pem"), key.private_to_pem(OpenSSL::Cipher.new("aes-256-cbc"), "senha comprida demais"))
      SuperAdmin.public_key = OpenSSL::PKey.read(key.public_to_pem)
      console = Object.new.tap { |c| c.define_singleton_method(:getpass) { |_prompt| "senha comprida demais" } }

      original_console = IO.method(:console)
      IO.define_singleton_method(:console) { console } # a senha "digitada" no terminal
      output = with_env("HOME" => home) do
        capture_io { Rake::Task["super_admin:conceder"].execute(Rake::TaskArguments.new([ :conta ], [ "dono@example.com" ])) }.first
      ensure
        IO.define_singleton_method(:console, original_console)
      end

      token = output[/^\s*(v1\.\S+)$/, 1]
      assert_equal owner.google_uid, SuperAdmin.verify(token).uid
      assert_not owner.super_admin?, "só vale depois de colocada em SUPER_ADMIN_GRANTS"
      ENV["SUPER_ADMIN_GRANTS"] = token
      assert owner.super_admin?
    end
  end

  private

  def with_env(vars)
    originals = vars.keys.index_with { ENV[it] }
    vars.each { |name, value| ENV[name] = value }
    yield
  ensure
    originals.each { |name, value| ENV[name] = value }
  end
end
