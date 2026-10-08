require "test_helper"

class TrackMapTest < ActionDispatch::IntegrationTest
  setup do
    base   = LearningModule.create!(code: "0", name: "BASE", position: 0)
    tricks = LearningModule.create!(code: "3", name: "PRIMEIRAS MANOBRAS", position: 3)
    setup_step = Maneuver.create!(learning_module: base, code: "0.1", slug: "t-setup", name: "SETUP", position: 0, kind: :drill)
    stance     = Maneuver.create!(learning_module: base, code: "1.0", slug: "t-postura", name: "POSTURA", position: 1,
                                  prerequisite: setup_step)
    @shove_it  = Maneuver.create!(learning_module: tricks, code: "3.0", slug: "t-shove-it", name: "SHOVE-IT", position: 0, description: "Gire a board 180 graus.",
                                  prerequisite: stance)
    Maneuver.create!(learning_module: tricks, code: "3.1", slug: "t-no-comply", name: "NO COMPLY", position: 1, prerequisite: @shove_it)

    post account_path, params: { user: { contact: "mapa@example.com", password: "manobra123", password_confirmation: "manobra123" } }
    @user = User.last
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
  end

  test "quem entra pelo diagnóstico avançado não vê check no que nunca treinou" do
    diagnosis = @user.create_diagnosis!(level: :advanced, setup: :store_board, completed_at: Time.current)
    DiagnosisPlanner.new(diagnosis).apply!

    get track_path
    assert_response :success
    assert_select ".map-node.is-completed", 0
    assert_select ".map-node.is-open", 2, "os 2 nós pulados ficam liberados (cadeado aberto)"
    assert_select ".map-node.is-current[title=?]", @shove_it.label
    assert_select ".map-node", text: "lock", count: 1
    assert_match "SHOVE-IT", css_select(".floating-lesson-card").text
  end
end
