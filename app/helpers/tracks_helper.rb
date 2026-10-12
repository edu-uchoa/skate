module TracksHelper
  # Mapa da trilha desenhado no próprio app (sem imagem de fundo), visto de cima como
  # os mapas de mundo dos videogames antigos, mas com cara de rua: cada módulo é uma
  # ilha da cidade, com prédios grafitados, pistas, obstáculos e sujeira
  # (TracksHelper::Scenery), e a rua em curvas liga as tarefas na ordem da trilha,
  # virando ponte nos canais entre as ilhas. Tudo é medido numa largura de MAP_WIDTH
  # e escala com a tela (aspect-ratio + posições em %), então a rua, as bolinhas e as
  # placas ficam sempre alinhadas, com quantas tarefas houver.
  MAP_WIDTH = 360

  TOP_WATER    = 16 # água acima da primeira ilha
  START_ROW    = 48 # placa "Largada"
  DISTRICT_ROW = 56 # rua transversal com a placa do módulo, no alto de cada ilha
  NODE_ROW     = 96 # distância entre duas tarefas
  FINISH_ROW   = 84 # placa "Chegada" e o fim da última ilha
  CANAL_ROW    = 68 # canal entre duas ilhas: a rua passa por uma ponte
  WALL         = 10 # paredão do cais, que aparece embaixo de cada ilha
  BOTTOM_WATER = 30

  # Posição de cada tarefa na largura do mapa (em %), em zigue-zague.
  WAVE = [ 50, 76, 50, 24 ].freeze

  MapPoint = Data.define(:x, :y) do
    def svg_x = (x * MAP_WIDTH / 100.0).round(1)
  end
  MapNode     = Data.define(:maneuver, :point, :label_side)
  MapDistrict = Data.define(:learning_module, :y, :crossing, :sign_side)
  MapIsland   = Data.define(:index, :top, :bottom, :left, :right)
  MapLayout   = Data.define(:height, :start, :finish, :nodes, :districts, :islands) do
    def points = [ start, *nodes.map(&:point), finish ]

    # Rua em curvas suaves passando pelo centro de cada bolinha, da largada à chegada.
    def road_path
      points.each_cons(2).reduce("M #{points.first.svg_x} #{points.first.y}") do |path, (from, to)|
        middle = (from.y + to.y) / 2.0
        "#{path} C #{from.svg_x} #{middle} #{to.svg_x} #{middle} #{to.svg_x} #{to.y}"
      end
    end

    # Canais entre duas ilhas: [onde acaba a de cima, onde começa a de baixo].
    def canals = islands.each_cons(2).map { |above, below| [ above.bottom, below.top ] }

    # Pontos ao longo da rua ([x, y] em unidades do mapa), mais ou menos a cada `step`.
    def road_samples(step = 4)
      points.each_cons(2).flat_map do |from, to|
        count = [ ((to.svg_x - from.svg_x).abs + (to.y - from.y)) / step, 1 ].max.ceil
        (0..count).map { |index| road_point(from, to, index.fdiv(count)) }
      end
    end

    # Onde a rua passa (x, em unidades do mapa) numa altura do mapa.
    def road_x_at(y)
      from, to = points.each_cons(2).find { |above, below| y.between?(above.y, below.y) } || [ finish, finish ]
      low, high = 0.0, 1.0
      20.times do
        middle = (low + high) / 2
        if road_point(from, to, middle).last < y then low = middle else high = middle end
      end
      road_point(from, to, low).first
    end

    private

    # Ponto da curva entre duas bolinhas (a mesma do road_path), com t de 0 a 1.
    def road_point(from, to, t)
      middle = (from.y + to.y) / 2.0
      x = from.svg_x + (to.svg_x - from.svg_x) * t * t * (3 - 2 * t)
      y = from.y * (1 - t)**3 + 3 * middle * t * (1 - t) + to.y * t**3
      [ x, y ]
    end
  end

  def track_map_layout(learning_modules)
    modules = learning_modules.reject { |learning_module| learning_module.maneuvers.empty? }
    top     = TOP_WATER
    start   = MapPoint.new(x: WAVE.first, y: top + START_ROW / 2)
    cursor  = top + START_ROW
    points, districts, islands = [], [], []

    modules.each_with_index do |learning_module, index|
      unless index.zero?
        islands << map_island(islands.size, top, cursor)
        cursor += CANAL_ROW
        top     = cursor
      end
      districts << [ learning_module, cursor + DISTRICT_ROW / 2 ]
      cursor += DISTRICT_ROW
      learning_module.maneuvers.each do |maneuver|
        points << [ maneuver, MapPoint.new(x: WAVE[points.size % WAVE.size], y: cursor + NODE_ROW / 2) ]
        cursor += NODE_ROW
      end
    end

    finish  = MapPoint.new(x: WAVE.first, y: cursor + 28)
    cursor += FINISH_ROW
    islands << map_island(islands.size, top, cursor)

    layout = MapLayout.new(
      height: cursor + WALL + BOTTOM_WATER, start: start, finish: finish, islands: islands, districts: [],
      nodes: points.each_with_index.map { |(maneuver, point), index| map_node(maneuver, point, points[index + 1]&.last) }
    )
    layout.with(districts: districts.map { |learning_module, y| map_district(learning_module, y, layout) })
  end

  # Prédios, pistas, obstáculos e sujeira das ilhas (sempre os mesmos para a mesma trilha).
  def track_map_scenery(layout) = Scenery.for(layout)

  # Contorno da ilha com a beira irregular, como as ilhas dos mapas de videogame.
  def map_island_outline(island)
    random = Random.new(island.index * 31 + 5)
    width  = island.right - island.left
    height = island.bottom - island.top
    rows   = [ (height / 48.0).round, 2 ].max
    wobble = -> { random.rand(0.0..5.0) }

    points =
      (0..8).map { |step| [ island.left + width * step / 8.0, island.top + wobble.call ] } +
      (1...rows).map { |step| [ island.right - wobble.call, island.top + height * step / rows.to_f ] } +
      (0..8).map { |step| [ island.right - width * step / 8.0, island.bottom - wobble.call ] } +
      (1...rows).map { |step| [ island.left + wobble.call, island.bottom - height * step / rows.to_f ] }
    middles = points.each_with_index.map do |(x, y), index|
      next_x, next_y = points[(index + 1) % points.size]
      [ (x + next_x) / 2, (y + next_y) / 2 ]
    end

    curves = points.each_with_index.map { |point, index| "Q #{map_coords(point)} #{map_coords(middles[index])}" }
    "M #{map_coords(middles.last)} #{curves.join(" ")} Z"
  end

  # Posição de um elemento do mapa (x em %, y nas unidades do mapa) em % da tela.
  def map_position(x, y, layout) = "left: #{x}%; #{map_top(y, layout)}"
  def map_top(y, layout) = "top: #{(y * 100.0 / layout.height).round(3)}%;"

  private

  def map_coords((x, y)) = "#{x.round(1)} #{y.round(1)}"

  # Cada ilha tem a beira num lugar um pouco diferente, para não parecerem todas iguais.
  def map_island(index, top, bottom)
    random = Random.new(index + 1)
    MapIsland.new(index: index, top: top, bottom: bottom,
                  left: 6 + random.rand(0..6), right: MAP_WIDTH - 6 - random.rand(0..6))
  end

  # O nome da tarefa vai para o lado em que a rua não passa.
  def map_node(maneuver, point, next_point)
    label_side =
      if point.x < 50 then :right
      elsif point.x > 50 then :left
      elsif next_point && next_point.x < 50 then :right
      else :left
      end

    MapNode.new(maneuver: maneuver, point: point, label_side: label_side)
  end

  # A placa fica do lado oposto ao ponto em que a rua da trilha cruza a do módulo.
  def map_district(learning_module, y, layout)
    crossing = layout.road_x_at(y)
    MapDistrict.new(learning_module: learning_module, y: y, crossing: crossing.round(1),
                    sign_side: crossing > MAP_WIDTH / 2 ? :left : :right)
  end
end
