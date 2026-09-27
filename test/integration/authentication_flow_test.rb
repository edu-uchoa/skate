require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"
  CODE     = "123456"

  def sign_up(contact, password: PASSWORD, confirmation: password)
    post account_path, params: { user: { contact: contact, password: password, password_confirmation: confirmation } }
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

    [ new_session_path, new_account_path, new_password_reset_path ].each do |path|
      get path
      assert_response :success, path
    end

    [ track_path, intro_path, install_path, onboarding_age_gate_path, store_path, spots_path,
      my_account_path, new_support_request_path ].each do |path|
      get path
      assert_redirected_to new_session_path, path
    end

    delete sign_out_path
    assert_redirected_to new_session_path
  end

  test "cadastro com e-mail e senha entra na plataforma" do
    sign_up("Skater@Example.com ")
    assert_redirected_to install_path

    user = User.last
    assert user.registered?
    assert_equal "skater@example.com", user.email
    assert user.authenticate(PASSWORD)

    get track_path
    assert_redirected_to onboarding_age_gate_path # logado; segue para o onboarding

    get my_account_path
    assert_response :success
    assert_match "skater@example.com", response.body
  end

  test "cadastro com telefone normaliza o número" do
    sign_up("(61) 99999-0000")
    assert_redirected_to install_path
    assert_equal "61999990000", User.last.phone
  end

  test "cadastro rejeita dados inválidos" do
    { "abc"      => "e-mail ou telefone válido",
      "123"      => "Informe um telefone com DDD",
      "x@"       => "Informe um e-mail válido",
      ""         => "Informe um e-mail ou telefone" }.each do |contact, message|
      sign_up(contact)
      assert_response :unprocessable_entity
      assert_match message, response.body
    end

    sign_up("a@b.com", password: "curta")
    assert_match "entre 8 e 72 caracteres", response.body

    sign_up("a@b.com", confirmation: "outrasenha")
    assert_match "confirmação não confere", response.body

    assert_equal 0, User.count
  end

  test "cadastro com contato já usado é recusado" do
    sign_up("dup@example.com")
    delete sign_out_path

    sign_up("DUP@example.com")
    assert_response :unprocessable_entity
    assert_match "já tem uma conta", response.body
    assert_equal 1, User.count
  end

  test "logout, login com senha e retorno à rota protegida" do
    sign_up("rider@example.com")
    delete sign_out_path
    assert_redirected_to root_path

    get my_account_path
    assert_redirected_to new_session_path

    sign_in("rider@example.com", password: "senhaerrada")
    assert_response :unprocessable_entity
    assert_match "incorretos", response.body

    sign_in("RIDER@example.com")
    assert_redirected_to my_account_path

    follow_redirect!
    assert_response :success
    assert_match "rider@example.com", response.body
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
    get new_account_path
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
