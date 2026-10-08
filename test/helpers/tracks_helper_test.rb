require "test_helper"

class TracksHelperTest < ActionView::TestCase
  setup do
    base   = LearningModule.create!(code: "0", name: "BASE", position: 0)
    tricks = LearningModule.create!(code: "3", name: "PRIMEIRAS MANOBRAS", position: 3)
    @maneuvers = [
      Maneuver.create!(learning_module: base,   code: "0.1", slug: "t-setup",    name: "SETUP",       position: 0),
      Maneuver.create!(learning_module: base,   code: "0.2", slug: "t-gear",     name: "EQUIPAMENTO", position: 1),
      Maneuver.create!(learning_module: tricks, code: "3.0", slug: "t-shove-it", name: "SHOVE-IT",    position: 0)
    ]
    @layout = track_map_layout(LearningModule.ordered.includes(:maneuvers))
  end

  test "o mapa desce de cima para baixo, na ordem da trilha" do
    assert_equal @maneuvers, @layout.nodes.map(&:maneuver)

    heights = [ @layout.start.y, *@layout.nodes.map { |node| node.point.y }, @layout.finish.y ]
    assert_equal heights.sort, heights, "da largada até a chegada, sempre descendo"
    assert_operator heights.last, :<, @layout.height
  end

  test "a rua sai da largada e passa pelo centro de cada bolinha" do
    road = @layout.road_path

    assert road.start_with?("M #{@layout.start.svg_x} #{@layout.start.y}")
    @layout.nodes.each { |node| assert_includes road, "#{node.point.svg_x} #{node.point.y}" }
    assert road.end_with?("#{@layout.finish.svg_x} #{@layout.finish.y}")
  end

  test "cada módulo tem a sua placa, antes da primeira tarefa dele" do
    assert_equal %w[0 3], @layout.districts.map { |district| district.learning_module.code }
    assert @layout.districts.last.y.between?(@layout.nodes[1].point.y, @layout.nodes[2].point.y)
  end

  test "o nome da tarefa fica do lado em que a rua não passa" do
    @layout.nodes.each do |node|
      assert_equal :right, node.label_side if node.point.x < 50
      assert_equal :left,  node.label_side if node.point.x > 50
    end
  end

  test "o nome do mapa sai com uma cor por letra" do
    lines = map_title_lines("Super Skate World")

    assert_equal 2, lines.size, "a primeira palavra numa linha, o resto na outra"
    assert_equal 15, lines.join.scan('class="is-').size
  end
end
