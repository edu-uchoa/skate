require "test_helper"

# Conta de mentor: sem Trilha, Picos e Gravar; o menu de baixo traz as funções da
# Zine do mentor (Todos, Na fila, Ofensivas e Chat).
class MentorNavTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    @mentor = User.register(contact: "mentor@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @mentor.update!(birth_year: 1990, role: :mentor)
  end

  def sign_in(user) = post(session_path, params: { session: { contact: user.contact, password: PASSWORD } })

  test "mentor entra direto na fila, mesmo sem ter feito as perguntas do aprendiz" do
    sign_in(@mentor)
    assert_redirected_to mentor_zine_path
    follow_redirect!
    assert_select ".screen-title", "Na fila"
  end

  test "Trilha, Picos e Gravar levam o mentor para a fila" do
    sign_in(@mentor)
    [ track_path, spots_path, new_recording_path ].each do |path|
      get path
      assert_redirected_to mentor_zine_path, path
    end
    post meetups_path, params: { meetup: { place_name: "Pista" } }
    assert_redirected_to mentor_zine_path, "marcar rolê também é só do aprendiz"
  end

  test "as outras telas de aprendiz e o cadastro também levam o mentor para a fila" do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                     position: 0, kind: :drill, description: "Monte o seu skate.")
    sign_in(@mentor)

    [ maneuver_path("t-setup"), new_maneuver_training_session_path("t-setup"), streak_path, tasks_path, new_schedule_path,
      new_comeback_path, store_path, onboarding_age_gate_path, onboarding_diagnosis_path ].each do |path|
      get path
      assert_redirected_to mentor_zine_path, path
    end
    assert_nil @mentor.reload.diagnosis, "abrir as perguntas não cria mais um diagnóstico vazio para o mentor"

    [ my_account_path, new_support_request_path, install_path ].each do |path|
      get path
      assert_response :success, "#{path} continua aberto para o mentor"
    end
  end

  test "o menu de baixo do mentor tem Perfil, Todos, Na fila, Ofensivas e Chat" do
    sign_in(@mentor)
    get my_account_path
    assert_select ".mentor-nav" do
      assert_select "a.nav-btn.active[href=?]", my_account_path
      assert_select "a[href=?]", mentor_zine_path(aba: "todos"), /Todos/
      assert_select "a.nav-fab-btn[href=?]", mentor_zine_path(aba: "fila")
      assert_select ".nav-fab-label", "Na fila"
      assert_select "a[href=?]", mentor_streak_justifications_path, /Ofensivas/
      assert_select "a[href=?]", mentor_chats_path, /Chat/
      [ track_path, spots_path, new_recording_path, zine_path ].each { |path| assert_select "a[href=?]", path, 0 }
    end
    assert_select "a[href=?][title='Zine do mentor']", mentor_zine_path, 0, "o atalho do topo fica só para o super admin"

    get mentor_zine_path(aba: "todos")
    assert_select ".screen-title", "Todos os vídeos"
    assert_select ".mentor-nav a.nav-btn.active[href=?]", mentor_zine_path(aba: "todos")
  end

  test "o super admin treina como aprendiz e ganha o menu de mentor só na área do mentor" do
    original = Rails.configuration.x.flipaai.super_admin_emails
    Rails.configuration.x.flipaai.super_admin_emails = [ "dono@example.com" ]
    owner = sign_up_with_google("dono@example.com", nickname: "dono")
    owner.update!(birth_year: 1990, terms_accepted_at: Time.current)
    owner.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)

    get my_account_path
    assert_select ".phone-bottom-nav a[href=?]", track_path
    assert_select ".mentor-nav", 0
    assert_select "a[href=?][title='Zine do mentor']", mentor_zine_path

    get mentor_zine_path
    assert_select ".mentor-nav .nav-fab-btn.is-active"
  ensure
    Rails.configuration.x.flipaai.super_admin_emails = original
  end

  test "o super admin que ainda não fez as perguntas não vê o menu de baixo, como todo aprendiz" do
    original = Rails.configuration.x.flipaai.super_admin_emails
    Rails.configuration.x.flipaai.super_admin_emails = [ "dono@example.com" ]
    sign_up_with_google("dono@example.com", nickname: "dono")

    [ edit_nickname_path, my_account_path ].each do |path|
      get path
      assert_select ".phone-bottom-nav", 0, path
    end

    get admin_root_path
    assert_select ".phone-bottom-nav", 1, "no painel o menu continua"
  ensure
    Rails.configuration.x.flipaai.super_admin_emails = original
  end
end
