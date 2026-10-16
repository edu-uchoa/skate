require "test_helper"

class InstallTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    @user = User.register(contact: "instalar@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    post session_path, params: { session: { contact: @user.contact, password: PASSWORD } }
  end

  test "a página ensina a instalar no iPhone, no Android e no computador" do
    get install_path

    assert_response :success
    assert_select "[data-controller=install]"
    assert_select "details.install-platform", 3
    assert_select "details[data-platform=ios]", text: /Compartilhar.*Adicionar à Tela de Início/m
    assert_select "details[data-platform=android]", text: /Instalar app/
    assert_select "details[data-platform=desktop]"
    # O botão de um toque só aparece quando o Android avisa que dá para instalar.
    assert_select "button[data-action='install#install'][hidden]"
    assert_no_match "apague seu progresso", response.body # promessa sem base, da versão antiga
  end

  test "logo depois do cadastro, dá para seguir no navegador" do
    get install_path
    assert_select "a.install-skip[href=?]", track_path # segue para as perguntas, sem passar pela Loja
    assert_select "a.auth-back", 0
  end

  test "quem já está na trilha volta para ela, e a trilha e o Perfil têm o atalho" do
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    base = LearningModule.create!(code: "0", name: "BASE", position: 0)
    base.maneuvers.create!(code: "0.1", slug: "t-setup", name: "SETUP", position: 0, description: "Monte o seu skate.")
    DiagnosisPlanner.new(@user.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)).apply!

    get install_path
    assert_select "a.auth-back[href=?]", track_path
    assert_select "a.install-skip", 0

    get track_path
    assert_select ".map-header a.install-pill[href=?]", install_path

    get my_account_path
    assert_select ".profile-account a.install-link[href=?]", install_path
  end
end
