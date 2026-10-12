require "test_helper"

class TrackMapTest < ActionDispatch::IntegrationTest
  setup do
    base   = LearningModule.create!(code: "0", name: "BASE", position: 0)
    tricks = LearningModule.create!(code: "3", name: "PRIMEIRAS MANOBRAS", position: 3)
    @setup    = Maneuver.create!(learning_module: base, code: "0.1", slug: "t-setup", name: "SETUP", position: 0,
                                 kind: :drill, description: "Monte o seu skate.")
    @stance   = Maneuver.create!(learning_module: base, code: "1.0", slug: "t-postura", name: "POSTURA", position: 1,
                                 description: "Ache a sua base.", prerequisite: @setup)
    @shove_it = Maneuver.create!(learning_module: tricks, code: "3.0", slug: "t-shove-it", name: "SHOVE-IT", position: 0,
                                 description: "Gire a board 180 graus.", prerequisite: @stance)
    @last     = Maneuver.create!(learning_module: tricks, code: "3.1", slug: "t-no-comply", name: "NO COMPLY", position: 1,
                                 description: "Pé da frente no chão.", prerequisite: @shove_it)

    post account_path, params: { user: { contact: "mapa@example.com", password: "manobra123", password_confirmation: "manobra123" } }
    @user = User.last
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    DiagnosisPlanner.new(@user.create_diagnosis!(level: :advanced, setup: :store_board, completed_at: Time.current)).apply!
  end

  def progression = TrackProgression.new(@user)

  test "a seta começa na 0.1, até para quem já manda ollie, e nada aparece concluído" do
    get track_path
    assert_response :success
    assert_select ".map-node.is-current[title=?]", @setup.label
    assert_select ".map-node.is-completed", 0
    assert_select ".map-node .map-node-icon", text: "lock", count: 3
    assert_match "0.1", css_select(".floating-lesson-card").text
  end

  test "o mapa desce de cima para baixo, com uma ilha e uma placa por módulo" do
    get track_path

    assert_select ".track-map[data-controller=track-map] .track-map-canvas"
    assert_select ".map-title", 0 # o nome "Super Skate World" saiu do mapa
    assert_select ".map-scene path.map-ground", 2 # uma ilha da cidade por módulo
    assert_select ".map-decoration", 0 # os ícones soltos saíram; o cenário é desenhado
    assert_operator css_select(".map-scene use").size, :>, 10
    assert_select ".map-sign", 2
    assert_select ".map-node", 4
    assert_select ".track-map img", 0 # o mapa não é mais uma imagem (com os ícones de Store, Profile...)

    tops = css_select(".map-node").map { |node| node["style"][/top: ([\d.]+)%/, 1].to_f }
    assert_equal tops.sort, tops, "as tarefas descem na ordem da trilha"
  end

  test "a seta só anda quando o mentor dá a devolutiva" do
    progression.complete!(@setup)

    get track_path
    assert_select ".map-node.is-completed[title=?]", @setup.label
    assert_select ".map-node.is-current[title=?]", @stance.label
  end

  test "avançar sem devolutiva pergunta antes, pula a tarefa e abre a próxima" do
    get maneuver_path(@setup)
    assert_select "form[action=?][data-turbo-confirm*='pular etapas'] button.maneuver-advance",
                  skip_maneuver_path(@setup), text: /Avançar para a próxima tarefa/

    post skip_maneuver_path(@setup)
    assert_redirected_to maneuver_path(@stance)
    assert_equal "skipped", progression.status_for(@setup)

    get track_path
    assert_select ".map-node.is-open[title=?]", @setup.label # pulada: cadeado aberto, sem check
    assert_select ".map-node.is-current[title=?]", @stance.label
  end

  test "tarefa concluída ou pulada avança sem aviso; bloqueada e a última não têm o botão" do
    progression.complete!(@setup)
    get maneuver_path(@setup)
    assert_select "a.maneuver-advance[href=?]", maneuver_path(@stance)
    assert_select "form[data-turbo-confirm] .maneuver-advance", 0

    get maneuver_path(@shove_it)
    assert_select ".maneuver-advance", 0, "bloqueada"

    @user.maneuver_progresses.find_by!(maneuver: @last).update!(status: :available)
    get maneuver_path(@last)
    assert_select ".maneuver-advance", 0, "última tarefa da trilha"
  end

  test "não dá para pular uma tarefa bloqueada pelo endereço" do
    post skip_maneuver_path(@shove_it)
    assert_equal "locked", progression.status_for(@shove_it)
  end
end
