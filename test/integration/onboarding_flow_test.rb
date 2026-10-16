require "test_helper"

# Do primeiro toque no app até a trilha: logo → Google → nickname → idade →
# perguntas → plano → trilha. O menu de baixo só aparece na trilha.
class OnboardingFlowTest < ActionDispatch::IntegrationTest
  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                     position: 0, kind: :drill, description: "Monte o seu skate.")
  end

  def assert_no_bottom_nav(where) = assert_select(".phone-bottom-nav", 0, "#{where}: sem o menu de baixo")

  test "a primeira tela é a logo com entrar pelo Google ou já tenho conta" do
    get root_path
    assert_response :success
    assert_select "img.splash-logo[alt=FlipaAi]"
    assert_select ".splash-actions form[action='/auth/google_oauth2'] button", /Continuar com o Google/
    assert_select ".splash-actions a[href=?]", new_session_path, text: "Já tenho conta"
    assert_no_bottom_nav "logo"

    get new_session_path
    assert_no_bottom_nav "entrar"
  end

  test "conta nova vai do nickname direto às perguntas, sem instalação nem Loja, e o menu volta na trilha" do
    sign_in_with_google("nova@example.com")
    follow_redirect!
    assert_equal edit_nickname_path, path
    assert_no_bottom_nav "nickname"

    patch nickname_path, params: { nickname: { nickname: "novata", tag: "" } }
    assert_redirected_to onboarding_age_gate_path
    follow_redirect!
    assert_match "Pronto! No FlipaAi você é novata#", response.body
    assert_no_bottom_nav "idade"

    patch onboarding_age_gate_path, params: { user: { birth_year: 2000 } }
    assert_redirected_to onboarding_diagnosis_path
    follow_redirect!
    assert_no_bottom_nav "perguntas"

    patch onboarding_diagnosis_path(step: "level"), params: { diagnosis: { level: "never_ridden" } }
    patch onboarding_diagnosis_path(step: "blockers"), params: { diagnosis: { blockers: [ "fear_of_falling" ] } }
    patch onboarding_diagnosis_path(step: "setup"), params: { diagnosis: { setup: "store_board" } }
    assert_redirected_to summary_onboarding_diagnosis_path
    follow_redirect!
    assert_no_bottom_nav "plano"

    get track_path
    assert_response :success
    assert_select ".phone-bottom-nav a.nav-btn.active[href=?]", track_path
    assert_no_match "14 DIAS", response.body
  end

  test "quem já entrou e abre o app pula a logo" do
    sign_up_with_google("volta@example.com")
    get root_path
    assert_redirected_to track_path
  end
end
