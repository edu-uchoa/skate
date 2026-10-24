require "test_helper"

# As telas do aprendiz só abrem depois do cadastro completo (idade, termos e as 3
# perguntas). Antes, um link antigo ou o atalho "Picos" do app instalado abria Perfil,
# Picos e Ofensiva sem a idade mínima e sem o aceite dos termos (LGPD).
class OnboardingGuardTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                     position: 0, kind: :drill, description: "Monte o seu skate.")
  end

  def account(contact, role: :learner)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap { it.update!(role: role) }
  end

  def sign_in(user) = post(session_path, params: { session: { contact: user.contact, password: PASSWORD } })

  def learner_pages
    [ my_account_path, spots_path, streak_path, new_support_request_path, store_path, new_mentor_application_path,
      zine_path, chat_path, tasks_path, new_schedule_path, new_comeback_path, maneuver_path("t-setup"),
      new_maneuver_training_session_path("t-setup"), track_path, new_recording_path ]
  end

  test "sem a idade e os termos, toda tela do aprendiz leva à tela de idade" do
    sign_in(account("sem-idade@example.com"))
    learner_pages.each do |path|
      get path
      assert_redirected_to onboarding_age_gate_path, path
    end
    post meetups_path, params: { meetup: { place_name: "Pista" } }
    assert_redirected_to onboarding_age_gate_path, "marcar rolê também espera o cadastro"
  end

  test "sem as 3 perguntas, toda tela do aprendiz leva às perguntas" do
    user = account("sem-perguntas@example.com")
    user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    sign_in(user)
    learner_pages.each do |path|
      get path
      assert_redirected_to onboarding_diagnosis_path, path
    end
  end

  test "termos, privacidade, apagar a conta e baixar os dados abrem a qualquer momento" do
    sign_in(account("livre@example.com"))
    [ terms_path, privacy_path, account_deletion_path ].each do |path|
      get path
      assert_response :success, path
    end
    get my_data_path(format: :json)
    assert_response :success
  end

  test "a conta de mentor não faz o cadastro de aprendiz: Perfil e Ajuda continuam abertos" do
    sign_in(account("mentor@example.com", role: :mentor))
    [ my_account_path, new_support_request_path ].each do |path|
      get path
      assert_response :success, path
    end
  end
end
