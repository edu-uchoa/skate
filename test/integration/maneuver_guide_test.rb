require "test_helper"

class ManeuverGuideTest < ActionDispatch::IntegrationTest
  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @setup = Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "escolher-setup",
                              name: "SETUP", position: 0, kind: :drill)
    @other = Maneuver.create!(learning_module: learning_module, code: "0.9", slug: "t-sem-guia",
                              name: "SEM GUIA", position: 1, kind: :drill)

    post account_path, params: { user: { contact: "guia@example.com", password: "manobra123", password_confirmation: "manobra123" } }
    User.last.update!(birth_year: 2000, terms_accepted_at: Time.current)
  end

  test "o passo 0.1 mostra o guia de setup abaixo do vídeo, com rua e bowl" do
    get maneuver_path(@setup)

    assert_response :success
    assert_select ".video-container + .guide"
    assert_select ".guide-panel-rua"
    assert_select ".guide-panel-bowl"
    assert_select ".guide-tab svg.icon-bowl", count: 1
    assert_select ".guide-details summary", text: /Passo a passo da montagem/
  end

  test "o passo 0.2 mostra o guia de equipamento com o kit de rua e de bowl" do
    equipment = Maneuver.create!(learning_module: @setup.learning_module, code: "0.2", slug: "equipamento",
                                 name: "EQUIPAMENTO", position: 2, kind: :drill)

    get maneuver_path(equipment)

    assert_response :success
    assert_select ".video-container + .guide"
    assert_select ".guide-panel-rua .guide-gear li", minimum: 3
    assert_select ".guide-panel-bowl .guide-gear-name", text: /Joelheira com capa de plástico/
    assert_select ".guide-card-label", text: /Onde e como comprar/
  end

  test "o passo 0.3 mostra o guia de queda controlada: medo, como cair e postura" do
    fall = Maneuver.create!(learning_module: @setup.learning_module, code: "0.3", slug: "queda-controlada",
                            name: "QUEDA CONTROLADA", position: 3, kind: :drill)

    get maneuver_path(fall)

    assert_response :success
    assert_select ".video-container + .guide"
    assert_select ".guide-card-label", text: /Diminua o medo/
    assert_select ".guide-panel-rua dt", text: "Role"
    assert_select ".guide-panel-bowl dt", text: "Joelhos"
    assert_select ".guide-card-label", text: /Solte as pernas/
    assert_select ".guide-details summary", text: /Treino de 10 minutos/
  end

  test "drill sem guia continua só com vídeo e botões" do
    get maneuver_path(@other)

    assert_response :success
    assert_select ".guide", count: 0
    assert_select ".video-container"
  end
end
