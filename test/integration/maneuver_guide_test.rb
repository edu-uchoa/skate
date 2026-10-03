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
    assert_select ".guide-details summary", text: /Passo a passo da montagem/
  end

  test "drill sem guia continua só com vídeo e botões" do
    get maneuver_path(@other)

    assert_response :success
    assert_select ".guide", count: 0
    assert_select ".video-container"
  end
end
