require "test_helper"

# Do primeiro toque no app até a trilha: logo → Google → nickname → idade →
# perguntas → plano → trilha. Os menus (de cima e de baixo) só aparecem na trilha.
class OnboardingFlowTest < ActionDispatch::IntegrationTest
  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                     position: 0, kind: :drill, description: "Monte o seu skate.")
  end

  # Antes da trilha, nem o menu de cima nem o de baixo.
  def assert_no_menus(where)
    assert_select ".phone-bottom-nav", 0, "#{where}: sem o menu de baixo"
    assert_select ".phone-header-bar", 0, "#{where}: sem o menu de cima"
  end

  test "a primeira tela é a logo com entrar pelo Google ou já tenho conta" do
    get root_path
    assert_response :success
    assert_select "img.splash-logo[alt=FlipaAi]"
    assert_select ".splash-actions form[action='/auth/google_oauth2'] button#landing-start", /Começar agora!/
    assert_select ".splash-actions form[action='/auth/google_oauth2'] button", "Já tenho conta"
    assert_no_menus "logo"
  end

  test "sem o Google configurado no servidor, o Começar agora! aparece desligado e com o aviso" do
    original = Rails.configuration.x.flipaai.google_client_id
    Rails.configuration.x.flipaai.google_client_id = nil
    get root_path
    assert_select "button.splash-start[disabled]", /Começar agora!/
    assert_select "form[action='/auth/google_oauth2']", 0
    assert_match "ainda não está configurado", response.body
  ensure
    Rails.configuration.x.flipaai.google_client_id = original
  end

  test "rota protegida sem login volta para a logo" do
    get track_path
    assert_redirected_to root_path
    follow_redirect!
    assert_match "Entre com a sua conta Google para continuar.", response.body
    assert_select "img.splash-logo"
  end

  test "conta nova vai do nickname direto às perguntas, sem instalação nem Loja, e o menu volta na trilha" do
    sign_in_with_google("nova@example.com")
    follow_redirect!
    assert_equal edit_nickname_path, path
    assert_no_menus "nickname"

    patch nickname_path, params: { nickname: { nickname: "novata", tag: "" } }
    assert_redirected_to onboarding_age_gate_path
    follow_redirect!
    assert_match "Pronto! No FlipaAi você é novata#", response.body
    assert_no_menus "idade"

    patch onboarding_age_gate_path, params: { user: { birth_year: 2000 } }
    assert_response :unprocessable_entity, "sem aceitar os termos não segue"
    assert_match "aceite os Termos de Uso e a Política de Privacidade", response.body

    patch onboarding_age_gate_path, params: { user: { birth_year: 2000 }, accept_terms: "1" }
    assert_redirected_to onboarding_diagnosis_path
    follow_redirect!
    assert_no_menus "perguntas"

    patch onboarding_diagnosis_path(step: "level"), params: { diagnosis: { level: "never_ridden" } }
    patch onboarding_diagnosis_path(step: "blockers"), params: { diagnosis: { blockers: [ "fear_of_falling" ] } }
    patch onboarding_diagnosis_path(step: "setup"), params: { diagnosis: { setup: "store_board" } }
    assert_redirected_to summary_onboarding_diagnosis_path
    follow_redirect!
    assert_no_menus "plano"

    get track_path
    assert_response :success
    assert_select ".phone-bottom-nav a.nav-btn.active[href=?]", track_path
    assert_select ".phone-header-bar", 1, "na trilha o menu de cima volta"
    assert_no_match "14 DIAS", response.body
  end

  test "pergunta enviada sem resposta avisa o que falta e fica na mesma tela" do
    sign_up_with_google("vazio@example.com").update!(birth_year: 2000, terms_accepted_at: Time.current)
    patch onboarding_diagnosis_path(step: "level"), params: { diagnosis: { level: "never_ridden" } }

    patch onboarding_diagnosis_path(step: "blockers"), params: { diagnosis: { blockers: [ "" ] } }
    assert_response :unprocessable_entity
    assert_select ".auth-errors", /Marque pelo menos uma opção/
    assert_select ".screen-title", "O que é mais difícil hoje?"

    patch onboarding_diagnosis_path(step: "setup"), params: { diagnosis: { setup: "" } }
    assert_select ".auth-errors", /Escolha como é o seu skate/
  end

  test "quem já entrou e abre o app pula a logo" do
    sign_up_with_google("volta@example.com")
    get root_path
    assert_redirected_to track_path
  end
end
