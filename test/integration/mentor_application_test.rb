require "test_helper"

class MentorApplicationTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  def sign_up(contact, account_type: nil)
    post account_path, params: { account_type: account_type,
                                 user: { contact: contact, password: PASSWORD, password_confirmation: PASSWORD } }
  end

  def sign_in(contact) = post session_path, params: { session: { contact: contact, password: PASSWORD } }

  def apply(birth_year:, note: "Ando há 10 anos e dou aula na pista do bairro.")
    post mentor_application_path, params: { mentor_application: { birth_year: birth_year, note: note } }
  end

  test "escolher mentor no cadastro leva ao pedido, sem dar acesso de mentor" do
    sign_up("candidato@example.com", account_type: "mentor")

    assert_redirected_to new_mentor_application_path
    assert User.last.role_learner?
    get mentor_zine_path
    assert_response :not_found
  end

  test "aprendiz continua indo para a instalação" do
    sign_up("aprendiz@example.com")
    assert_redirected_to install_path
  end

  test "o pedido exige 18 anos e a experiência no skate" do
    sign_up("novinho@example.com", account_type: "mentor")

    apply(birth_year: Date.current.year - 16)
    assert_response :unprocessable_entity
    assert_match "18 anos ou mais", response.body

    apply(birth_year: 1990, note: "")
    assert_match "experiência no skate", response.body
    assert_not User.last.mentor_requested?
  end

  test "pedido enviado fica em análise até um mentor aprovar" do
    sign_up("candidato@example.com", account_type: "mentor")
    apply(birth_year: 1990)

    assert_redirected_to new_mentor_application_path
    follow_redirect!
    assert_select ".screen-title", "Pedido em análise"
    candidate = User.find_by(email: "candidato@example.com")
    assert candidate.mentor_requested?

    get mentor_zine_path
    assert_response :not_found, "pedido pendente não dá acesso aos vídeos"
    patch mentor_request_path(candidate)
    assert_response :not_found, "candidato não pode se aprovar"
    assert candidate.reload.role_learner?
  end

  test "mentor vê o pedido, aprova e o candidato passa a ter acesso" do
    sign_up("candidato@example.com", account_type: "mentor")
    apply(birth_year: 1990)
    candidate = User.find_by(email: "candidato@example.com")
    delete sign_out_path

    sign_up("mentor@example.com")
    User.find_by(email: "mentor@example.com").role_mentor!
    get mentor_requests_path
    assert_select ".guide-tab.is-active", /Pedidos \(1\)/
    assert_select "#" + ActionView::RecordIdentifier.dom_id(candidate, :mentor_request) do
      assert_select ".auth-card-value", "candidato@example.com"
      assert_match "dou aula na pista", response.body
    end

    patch mentor_request_path(candidate)
    assert_redirected_to mentor_requests_path
    assert candidate.reload.role_mentor?
    assert_nil candidate.mentor_requested_at

    delete sign_out_path
    sign_in("candidato@example.com")
    get mentor_zine_path
    assert_response :success
  end

  test "mentor recusa o pedido e a conta segue como aprendiz" do
    sign_up("candidato@example.com", account_type: "mentor")
    apply(birth_year: 1990)
    candidate = User.find_by(email: "candidato@example.com")
    delete sign_out_path

    sign_up("mentor@example.com")
    User.find_by(email: "mentor@example.com").role_mentor!
    delete mentor_request_path(candidate)

    assert candidate.reload.role_learner?
    assert_not candidate.mentor_requested?
    patch mentor_request_path(candidate)
    assert_response :not_found, "só dá para aprovar quem tem pedido pendente"
  end
end
