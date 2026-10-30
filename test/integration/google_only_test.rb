require "test_helper"

# Só pelo Google (config.x.flipaai.google_only, ligado no app publicado): as telas de
# login com senha e de recuperar senha respondem 404.
class GoogleOnlyTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    @user = User.register(contact: "antiga@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    Rails.configuration.x.flipaai.google_only = true
  end

  teardown { Rails.configuration.x.flipaai.google_only = false }

  test "sem login com senha: a tela não abre e a senha certa não entra" do
    get new_session_path
    assert_response :not_found

    post session_path, params: { session: { contact: @user.contact, password: PASSWORD } }
    assert_response :not_found
    assert_nil cookies[Authentication::COOKIE.to_s].presence, "não entrou"
  end

  test "sem recuperar senha: nenhuma tela abre e nenhum código é criado" do
    get new_password_reset_path
    assert_response :not_found

    post password_reset_path, params: { password_reset: { contact: @user.contact } }
    assert_response :not_found
    assert_equal 0, AccessCode.count

    get edit_password_reset_path
    assert_response :not_found
    patch password_reset_path, params: { password_reset: { code: "000000" } }
    assert_response :not_found
    post resend_password_reset_path
    assert_response :not_found
  end

  test "o Google continua sendo a porta de entrada" do
    sign_in_with_google("nova@example.com")
    assert_redirected_to edit_nickname_path
    assert User.find_by!(email: "nova@example.com").google?
  end

  test "no computador e nos testes, as telas de senha continuam" do
    Rails.configuration.x.flipaai.google_only = false

    get new_session_path
    assert_response :success
    get new_password_reset_path
    assert_response :success
  end
end
