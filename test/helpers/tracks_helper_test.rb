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

  test "cada módulo é uma ilha, e a rua passa de uma para a outra por uma ponte" do
    assert_equal 2, @layout.islands.size
    above, below = @layout.islands
    assert_equal [ [ above.bottom, below.top ] ], @layout.canals
    assert_operator above.bottom, :<, below.top

    @layout.nodes.first(2).each { |node| assert node.point.y.between?(above.top, above.bottom) }
    assert @layout.nodes.last.point.y.between?(below.top, below.bottom)
    assert @layout.finish.y.between?(below.top, below.bottom)
  end

  test "o cenário tem grafite, obstáculos e sujeira, sem cobrir a rua nem as tarefas" do
    pieces = track_map_scenery(@layout)
    kinds  = pieces.map(&:kind)

    assert_includes kinds, :graffiti_wall
    assert (kinds & %i[skatepark halfpipe funbox ledge rail stairs kicker]).any?, "obstáculos de skate"
    assert (kinds & %i[stain crack litter pothole]).any?, "sujeira na rua"

    road = @layout.road_samples
    pieces.select { |piece| piece.layer == :object }.each do |piece|
      area = piece.box.grow(18) # metade da rua, com a calçada
      assert road.none? { |x, y| x.between?(area.x, area.right) && y.between?(area.y, area.bottom) }, "#{piece.kind} em cima da rua"
      @layout.nodes.each do |node|
        task = TracksHelper::Scenery::Box.new(x: node.point.svg_x - 20, y: node.point.y - 20, width: 40, height: 40)
        refute piece.box.overlaps?(task), "#{piece.kind} em cima da tarefa #{node.maneuver.code}"
      end
    end
  end

  test "o cenário sai sempre igual para a mesma trilha" do
    assert_equal TracksHelper::Scenery.new(@layout).pieces, TracksHelper::Scenery.new(@layout).pieces
  end
end
