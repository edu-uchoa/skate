require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"
  CODE     = "123456"

  # Contas de antes do login pelo Google: e-mail ou telefone + senha, e já logada.
  def sign_up(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      assert user.persisted?, user.errors.full_messages.to_sentence
      sign_in(contact)
    end
  end

  def sign_in(contact, password: PASSWORD)
    post session_path, params: { session: { contact: contact, password: password } }
  end

  # O código real só existe em memória (e no log); fixa um conhecido.
  def pin_latest_code
    AccessCode.order(:id).last.update!(code_digest: BCrypt::Password.create(CODE))
  end

  test "sem conta, só a landing e as telas de acesso são públicas" do
    get root_path
    assert_response :success
    assert_equal 0, User.count, "visitante não deve gerar perfil anônimo"

    [ new_session_path, new_password_reset_path ].each do |path| # login com senha das contas antigas
      get path
      assert_response :success, path
    end

    [ track_path, intro_path, install_path, onboarding_age_gate_path, store_path, spots_path,
      my_account_path, tasks_path, streak_path, chat_path, new_support_request_path ].each do |path|
      get path
      assert_redirected_to root_path, path
    end

    delete sign_out_path
    assert_redirected_to root_path
  end

  test "a entrada é só pela logo, com o Google: não há mais tela de cadastro nem de login" do
    get "/cadastro"
    assert_redirected_to root_path
    get "/entrar"
    assert_redirected_to root_path

    get root_path
    assert_select "form[action='/auth/google_oauth2'][method=post]", 2 # Continuar com o Google e Já tenho conta
    assert_select "input[type=password]", 0
    assert_select "a[href=?]", new_session_path, 0, "o login com senha não tem link no app"

    post "/cadastro", params: { user: { contact: "novo@example.com", password: PASSWORD, password_confirmation: PASSWORD } }
    assert_response :not_found
    assert_equal 0, User.count
  end

  test "conta antiga com e-mail e senha ainda entra" do
    user = sign_up("Skater@Example.com ")
    assert_redirected_to track_path
    assert_equal "skater@example.com", user.email

    get track_path
    assert_redirected_to onboarding_age_gate_path # logado; segue para o onboarding

    get my_account_path
    assert_response :success
    assert_select "form[action='/auth/google_oauth2']", 1, "o Perfil oferece ligar a conta ao Google"
  end

  test "conta antiga com telefone entra com o número formatado" do
    User.register(contact: "61999990000", password: PASSWORD, password_confirmation: PASSWORD)
    sign_in("(61) 99999-0000")
    assert_redirected_to track_path
  end

  test "logout, login com senha e retorno à rota protegida" do
    sign_up("rider@example.com")
    delete sign_out_path
    assert_redirected_to root_path

    get my_account_path
    assert_redirected_to root_path

    sign_in("rider@example.com", password: "senhaerrada")
    assert_response :unprocessable_entity
    assert_match "incorretos", response.body

    sign_in("RIDER@example.com")
    assert_redirected_to my_account_path

    follow_redirect!
    assert_response :success
    assert_match "rider@example.com", response.body
  end

  test "pedido HEAD a uma rota protegida também guarda a volta após o login" do
    sign_up("head@example.com")
    delete sign_out_path

    head my_account_path
    assert_redirected_to root_path

    sign_in("head@example.com")
    assert_redirected_to my_account_path
  end

  test "login com contato inexistente mostra a mesma mensagem" do
    sign_in("ninguem@example.com")
    assert_response :unprocessable_entity
    assert_match "incorretos", response.body
  end

  test "quem já entrou não vê cadastro/login" do
    sign_up("in@example.com")
    get new_session_path
    assert_redirected_to track_path
    get root_path
    assert_redirected_to track_path
  end

  test "recuperar senha com código" do
    sign_up("reset@example.com")
    delete sign_out_path

    post password_reset_path, params: { password_reset: { contact: "reset@example.com" } }
    assert_redirected_to edit_password_reset_path
    pin_latest_code

    # Senha fraca não gasta o código.
    patch password_reset_path, params: { code: CODE, password: "curta", password_confirmation: "curta" }
    assert_response :unprocessable_entity

    patch password_reset_path, params: { code: "000000", password: "novasenha1", password_confirmation: "novasenha1" }
    assert_response :unprocessable_entity
    assert_match "Código inválido", response.body

    patch password_reset_path, params: { code: CODE, password: "novasenha1", password_confirmation: "novasenha1" }
    assert_redirected_to track_path

    delete sign_out_path
    sign_in("reset@example.com")
    assert_response :unprocessable_entity
    sign_in("reset@example.com", password: "novasenha1")
    assert_redirected_to track_path
  end

  test "conta ligada ao Google não ganha senha pelo esqueci minha senha" do
    sign_up_with_google("gmail@example.com")
    delete sign_out_path

    post password_reset_path, params: { password_reset: { contact: "gmail@example.com" } }
    assert_redirected_to edit_password_reset_path
    assert_equal 0, AccessCode.count

    patch password_reset_path, params: { code: CODE, password: "novasenha1", password_confirmation: "novasenha1" }
    assert_response :unprocessable_entity
    assert_nil User.find_by(email: "gmail@example.com").password_digest
  end

  test "recuperar senha não revela se o contato existe" do
    post password_reset_path, params: { password_reset: { contact: "fantasma@example.com" } }
    assert_redirected_to edit_password_reset_path
    assert_equal 0, AccessCode.count
  end

  test "sair de todos os aparelhos invalida o token" do
    sign_up("all@example.com")
    user = User.last
    old_token = user.token

    delete sign_out_everywhere_path
    assert_redirected_to root_path
    assert_not_equal old_token, user.reload.token
  end
end
