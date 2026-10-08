module TracksHelper
  # Mapa da trilha desenhado no próprio app (sem imagem de fundo): desce de cima
  # para baixo, com uma rua em curvas que liga as tarefas na ordem da trilha e uma
  # rua transversal com a placa de cada módulo. Tudo é medido numa largura de
  # MAP_WIDTH e escala com a tela (aspect-ratio + posições em %), então a rua, as
  # bolinhas e as placas ficam sempre alinhadas, com quantas tarefas houver.
  MAP_WIDTH = 360

  # Nome do mapa, em letras coloridas: a primeira palavra fica numa linha e o resto
  # na de baixo. Para trocar o nome, mude só aqui.
  MAP_TITLE = "Super Skate World".freeze

  TITLE_HEIGHT = 112 # espaço do nome no topo
  START_ROW    = 40  # placa "Largada"
  DISTRICT_ROW = 64  # rua transversal com a placa do módulo
  NODE_ROW     = 96  # distância entre duas tarefas
  FINISH_ROW   = 96  # placa "Chegada" e margem de baixo

  # Posição de cada tarefa na largura do mapa (em %), em zigue-zague.
  WAVE = [ 50, 76, 50, 24 ].freeze

  # Enfeites da cidade ao lado da rua (ícones Material Symbols), em rodízio.
  DECORATIONS = %w[park apartment storefront forest local_cafe park deck stadium].freeze
  TREES = %w[park forest].freeze

  TITLE_COLORS = %w[red yellow green blue orange].freeze

  MapPoint = Data.define(:x, :y) do
    def svg_x = (x * MAP_WIDTH / 100.0).round(1)
  end
  MapNode     = Data.define(:maneuver, :point, :label_side, :decoration)
  MapDistrict = Data.define(:learning_module, :y, :sign_side)
  MapLayout   = Data.define(:height, :start, :finish, :nodes, :districts) do
    # Rua em curvas suaves passando pelo centro de cada bolinha, da largada à chegada.
    def road_path
      points = [ start, *nodes.map(&:point), finish ]
      points.each_cons(2).reduce("M #{points.first.svg_x} #{points.first.y}") do |path, (from, to)|
        middle = (from.y + to.y) / 2.0
        "#{path} C #{from.svg_x} #{middle} #{to.svg_x} #{middle} #{to.svg_x} #{to.y}"
      end
    end
  end

  def track_map_layout(learning_modules)
    cursor    = TITLE_HEIGHT
    start     = MapPoint.new(x: WAVE.first, y: cursor + START_ROW / 2)
    cursor   += START_ROW
    points    = []
    districts = []

    learning_modules.each do |learning_module|
      next if learning_module.maneuvers.empty?

      districts << [ learning_module, cursor + DISTRICT_ROW / 2, points.size ]
      cursor += DISTRICT_ROW
      learning_module.maneuvers.each do |maneuver|
        points << [ maneuver, MapPoint.new(x: WAVE[points.size % WAVE.size], y: cursor + NODE_ROW / 2) ]
        cursor += NODE_ROW
      end
    end

    finish = MapPoint.new(x: WAVE.first, y: cursor + 28)
    MapLayout.new(
      height: cursor + FINISH_ROW, start: start, finish: finish,
      nodes: points.each_with_index.map { |(maneuver, point), index| map_node(maneuver, point, points[index + 1]&.last, index) },
      districts: districts.map { |learning_module, y, first| map_district(learning_module, y, points, first, start) }
    )
  end

  # Posição de um elemento do mapa (x em %, y nas unidades do mapa) em % da tela.
  def map_position(x, y, layout) = "left: #{x}%; #{map_top(y, layout)}"
  def map_top(y, layout) = "top: #{(y * 100.0 / layout.height).round(3)}%;"

  # Nome do mapa com cada letra numa cor, como nos jogos de skate antigos.
  def map_title_lines(title = MAP_TITLE)
    first, rest = title.split(" ", 2)
    index = -1
    [ first, rest ].compact.map do |line|
      safe_join(line.split(" ").map do |word|
        tag.span(class: "map-title-word") do
          safe_join(word.chars.map { |char| tag.span(char, class: "is-#{TITLE_COLORS[(index += 1) % TITLE_COLORS.size]}") })
        end
      end, " ")
    end
  end

  private

  # O nome da tarefa vai para o lado em que a rua não passa; o enfeite, para o outro.
  def map_node(maneuver, point, next_point, index)
    label_side =
      if point.x < 50 then :right
      elsif point.x > 50 then :left
      elsif next_point && next_point.x < 50 then :right
      else :left
      end
    decoration_x = { [ :left, true ] => 82, [ :left, false ] => 92, [ :right, true ] => 18, [ :right, false ] => 8 }
    icon = DECORATIONS[index % DECORATIONS.size]

    MapNode.new(maneuver: maneuver, point: point, label_side: label_side,
                decoration: { icon: icon, tree: TREES.include?(icon), x: decoration_x[[ label_side, point.x == 50 ]] })
  end

  # A placa fica do lado oposto ao ponto em que a rua cruza a transversal.
  def map_district(learning_module, y, points, first_index, start)
    before = first_index.zero? ? start : points[first_index - 1].last
    after  = points[first_index].last
    crossing = (before.x + after.x) / 2.0

    MapDistrict.new(learning_module: learning_module, y: y, sign_side: crossing > 50 ? :left : :right)
  end
end
