require "test_helper"

# Só para convidados (config.x.flipaai.invite_only, ligado no app publicado): só entra
# quem o super admin liberou em /painel/acesso (AllowedEmail), e o próprio super admin.
class AccessListTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup { Rails.configuration.x.flipaai.invite_only = true }
  teardown { Rails.configuration.x.flipaai.invite_only = false }

  def password_account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      complete_onboarding(user)
    end
  end

  test "pelo Google, quem não foi liberado não entra e nada dele fica guardado" do
    sign_in_with_google("estranho@example.com")
    assert_redirected_to root_path
    assert_match "só para convidados", flash[:alert]
    assert_nil User.find_by(email: "estranho@example.com")

    AllowedEmail.create!(email: " Estranho@Example.com ")
    sign_in_with_google("estranho@example.com")
    assert_redirected_to edit_nickname_path
    assert User.find_by!(email: "estranho@example.com").google?
  end

  test "o super admin entra mesmo com a lista vazia" do
    grant_super_admin("google-dono@example.com")
    assert_empty AllowedEmail.all

    sign_in_with_google("dono@example.com")
    assert_redirected_to edit_nickname_path
    assert User.find_by!(email: "dono@example.com").super_admin?
  end

  test "tirar da lista corta o acesso na hora, e a conta e os dados continuam" do
    allowed = AllowedEmail.create!(email: "aprendiz@example.com")
    user = sign_up_with_google("aprendiz@example.com")
    complete_onboarding(user)
    get track_path
    assert_response :success

    allowed.destroy!
    get track_path
    assert_redirected_to root_path, "quem já estava logado também sai"
    assert User.exists?(user.id)

    sign_in_with_google("aprendiz@example.com")
    assert_match "só para convidados", flash[:alert]
  end

  test "conta antiga com senha também precisa estar na lista, sem revelar quem tem conta" do
    user = password_account("antiga@example.com")

    post session_path, params: { session: { contact: user.contact, password: "senha-errada" } }
    assert_match "incorretos", response.body

    post session_path, params: { session: { contact: user.contact, password: PASSWORD } }
    assert_response :unprocessable_entity
    assert_match "só para convidados", response.body
    assert_nil cookies[Authentication::COOKIE.to_s].presence, "não entrou"

    AllowedEmail.create!(email: "antiga@example.com")
    post session_path, params: { session: { contact: user.contact, password: PASSWORD } }
    assert_redirected_to track_path
  end

  test "apagar a conta tira o e-mail da lista" do
    AllowedEmail.create!(email: "sai@example.com")
    sign_up_with_google("sai@example.com").destroy!
    assert_not AllowedEmail.exists?(email: "sai@example.com")
  end

  test "no painel, o super admin libera e tira e-mails; só @gmail.com, sem repetir" do
    grant_super_admin("google-dono@example.com")
    sign_up_with_google("dono@example.com", nickname: "dono")
    AllowedEmail.create!(email: "ja-entrou@example.com")
    entered = User.create!(email: "ja-entrou@example.com", google_uid: "google-ja-entrou", registered_at: Time.current)
    entered.choose_nickname(nickname: "Rato", tag: "0420")

    get admin_allowed_emails_path
    assert_response :success
    assert_select ".guide-tab.is-active", /Acesso/
    assert_select ".admin-user", 1
    assert_select ".admin-user", /Entrou como Rato#0420/

    post admin_allowed_emails_path, params: { allowed_email: { email: " Amiga@Example.com " } }
    assert_redirected_to admin_allowed_emails_path
    assert AllowedEmail.exists?(email: "amiga@example.com")
    follow_redirect!
    assert_select ".admin-user", /amiga@example.com.*Ainda não entrou/m

    post admin_allowed_emails_path, params: { allowed_email: { email: "amiga@example.com" } }
    assert_response :unprocessable_entity
    assert_select ".auth-errors", /já está na lista/

    post admin_allowed_emails_path, params: { allowed_email: { email: "professor@escola.edu.br" } }
    assert_select ".auth-errors", /Só e-mails @gmail.com/
    post admin_allowed_emails_path, params: { allowed_email: { email: "sem-arroba" } }
    assert_select ".auth-errors", /e-mail completo/
    assert_equal 2, AllowedEmail.count

    delete admin_allowed_email_path(AllowedEmail.find_by!(email: "amiga@example.com"))
    assert_redirected_to admin_allowed_emails_path
    assert_not AllowedEmail.exists?(email: "amiga@example.com")
  end

  test "a lista de acesso não existe para quem não é super admin" do
    allowed = AllowedEmail.create!(email: "mentor@example.com")
    mentor = password_account("mentor@example.com").tap(&:role_admin!)
    post session_path, params: { session: { contact: mentor.contact, password: PASSWORD } }

    get admin_allowed_emails_path
    assert_response :not_found
    post admin_allowed_emails_path, params: { allowed_email: { email: "outra@example.com" } }
    assert_response :not_found
    delete admin_allowed_email_path(allowed)
    assert_response :not_found
    assert_equal [ "mentor@example.com" ], AllowedEmail.pluck(:email)
  end

  test "fora do app publicado (no computador e nos testes), a lista não barra ninguém" do
    Rails.configuration.x.flipaai.invite_only = false
    sign_in_with_google("qualquer@example.com")
    assert_redirected_to edit_nickname_path
  end
end
