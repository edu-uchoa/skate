require "test_helper"

class ProfileTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                                 position: 0, kind: :drill, description: "Monte o seu skate.")
    @user = User.register(contact: "perfil@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    @user.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
    post session_path, params: { session: { contact: @user.contact, password: PASSWORD } }
  end

  test "a aba Perfil fica no lugar de Início e abre a conta" do
    get track_path
    assert_select ".phone-bottom-nav a[href=?]", my_account_path, text: /Perfil/
    assert_select ".phone-bottom-nav .nav-label", text: "Início", count: 0
  end

  test "o perfil mostra nível, XP, ofensiva, estilo, tarefas e o rank reservado" do
    TrackProgression.new(@user).sync!.complete!(@maneuver)

    get my_account_path
    assert_response :success
    assert_select ".profile-hero .screen-title", "Nível 1"
    assert_select ".profile-xp-label", /50 XP · faltam 50 para o nível 2/
    assert_select ".profile-xp[aria-valuenow='50']"
    assert_select "a.profile-stat.is-button[href=?]", streak_path, text: /0 sessões\s*Ofensiva · Comece agora/
    assert_select ".profile-stat", text: /Descobrindo\s*Estilo favorito/
    assert_select ".profile-stat", text: /1 de 1\s*Tarefas concluídas/
    assert_select ".profile-stat.is-soon", text: /Em breve\s*Rank/
    assert_select ".profile-account .auth-card-value", @user.contact
  end

  test "salvar o avatar guarda só opções válidas e o desenho mostra o que foi escolhido" do
    patch avatar_path, params: { avatar: { base: "masculino", hair: "moicano", head: "nenhum", beard: "cheia",
                                           vitiligo: "true", skin: "invalida", admin: "true" } }
    assert_redirected_to my_account_path(anchor: "personalizar")

    @user.reload
    assert_equal "masculino", @user.avatar_options["base"]
    assert_equal true, @user.avatar_options["vitiligo"]
    assert_equal Avatar::DEFAULTS[:skin], @user.avatar_options["skin"]
    assert_not @user.avatar_options.key?("admin")

    get my_account_path
    assert_select ".profile-hero svg.avatar[data-base=masculino][data-head=nenhum]"
    assert_select ".profile-hero [data-part=hair]", 1, "fora do editor, só a camada escolhida vai para a página"
    assert_select ".profile-hero [data-part=hair][data-option=moicano]"
    # No editor vão todas as opções (alguns cabelos têm camada de trás e da frente), para a prévia trocar na hora.
    editor_hair = css_select(".profile-preview [data-part=hair]").map { |layer| layer["data-option"] }.uniq
    assert_equal Avatar::OPTIONS[:hair].map(&:key).sort, editor_hair.sort
  end

  test "salvar o skate volta para a aba Skate" do
    patch deck_path, params: { deck: { type: "old_school", wheels: "laranja", trucks: "dourado" } }
    assert_redirected_to my_account_path(aba: "skate", anchor: "personalizar")
    assert_equal({ "type" => "old_school", "wheels" => "laranja", "trucks" => "dourado" }, @user.reload.board_options)

    follow_redirect!
    assert_select "#profile-tab-skate[checked]"
    assert_select "input[name='deck[type]'][value=old_school][checked]"
  end

  test "a trilha mostra a ofensiva de verdade, e nada quando é zero" do
    get track_path
    assert_select ".streak-pill", 0

    @user.skate_sessions.create!(skated_on: Date.current)
    get track_path
    assert_select "a.streak-pill[href=?]", streak_path, text: /🔥 1/
  end
end
