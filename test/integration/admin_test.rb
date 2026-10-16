require "test_helper"
require "rake"

class AdminTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:promover")
    @admin     = account("admin@example.com").tap(&:role_admin!)
    @mentor    = account("mentor@example.com").tap { |user| user.approve_mentor!(by: @admin) }
    @candidate = account("candidato@example.com").tap { |user| user.request_mentor(birth_year: 1990, note: "Dou aula na pista.") }
  end

  teardown do
    %w[admin:promover admin:remover mentor:remover].each { |task| Rake::Task[task].reenable }
  end

  def account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 1990, terms_accepted_at: Time.current)
    end
  end

  def sign_in(user) = post session_path, params: { session: { contact: user.contact, password: PASSWORD } }

  test "mentor comum não vê nem aprova pedidos de mentor" do
    sign_in(@mentor)

    get mentor_zine_path
    assert_response :success
    assert_select "a[href=?]", mentor_requests_path, count: 0

    get mentor_requests_path
    assert_response :not_found
    patch mentor_request_path(@candidate)
    assert_response :not_found
    assert @candidate.reload.role_learner?
  end

  test "administrador tem as funções de mentor e aprova guardando quem aprovou" do
    sign_in(@admin)

    get mentor_zine_path
    assert_response :success
    assert_select "a.icon-btn[href=?][title=Mentores]", mentor_requests_path

    patch mentor_request_path(@candidate)
    @candidate.reload
    assert @candidate.role_mentor?
    assert_equal @admin, @candidate.mentor_approved_by
    assert_not_nil @candidate.mentor_approved_at

    get mentor_requests_path
    assert_select "#" + ActionView::RecordIdentifier.dom_id(@mentor, :active_mentor), /por admin@example.com/
  end

  test "remover um mentor corta o acesso na hora, até na sessão já aberta" do
    sign_in(@mentor)
    get mentor_zine_path
    assert_response :success
    mentor_session = cookies.to_hash

    delete sign_out_path
    sign_in(@admin)
    delete mentor_mentor_path(@mentor)
    assert_redirected_to mentor_requests_path
    assert @mentor.reload.role_learner?

    delete sign_out_path
    mentor_session.each { |name, value| cookies[name] = value }
    get mentor_zine_path
    assert_redirected_to root_path, "o cookie antigo do mentor não vale mais"
  end

  test "administrador não pode ser removido pela tela de mentores" do
    sign_in(@admin)
    other_admin = account("outro.admin@example.com").tap(&:role_admin!)

    delete mentor_mentor_path(other_admin)
    assert_response :not_found
    assert other_admin.reload.role_admin?
  end

  test "não existe caminho no app para virar administrador" do
    post "/cadastro", params: { account_type: "admin",
                                user: { contact: "esperto@example.com", password: PASSWORD, password_confirmation: PASSWORD, role: "admin" } }
    assert_response :not_found, "não há mais cadastro com senha"
    assert_nil User.find_by(email: "esperto@example.com")

    sign_up_with_google("esperto@example.com")
    assert User.find_by(email: "esperto@example.com").role_learner?
  end

  test "administrador é criado e removido pelo terminal" do
    user = account("dono@example.com")

    assert_output(/agora é administrador/) { Rake::Task["admin:promover"].invoke("dono@example.com") }
    assert user.reload.role_admin?

    assert_output(/voltou a ser aprendiz/) { Rake::Task["admin:remover"].invoke("dono@example.com") }
    assert user.reload.role_learner?
  end
end
