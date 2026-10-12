module TracksHelper
  # Cenário das ilhas do mapa da trilha: prédios grafitados, pistas e obstáculos de
  # skate, praças, árvores e a sujeira da rua (manchas, rachaduras, buracos e lixo).
  # As peças são sorteadas com uma semente fixa por ilha, então o mapa sai sempre
  # igual, e nunca cobrem a rua, as bolinhas, os nomes das tarefas nem as placas. O
  # desenho de cada peça fica em app/views/tracks/_map_symbols.html.erb.
  class Scenery
    Box = Data.define(:x, :y, :width, :height) do
      def right  = x + width
      def bottom = y + height
      def grow(by) = with(x: x - by, y: y - by, width: width + 2 * by, height: height + 2 * by)
      def overlaps?(other) = x < other.right && other.x < right && y < other.bottom && other.y < bottom
    end

    # layer: patch (forra o chão), decal (pintado no chão), road (na rua da trilha),
    # object (prédios, pistas, árvores...) e water (barcos nos canais).
    Piece = Data.define(:kind, :layer, :box, :style) do
      def symbol = "map-#{kind.to_s.dasherize}"
    end

    # Tamanho de cada peça, em unidades do mapa (o mesmo do viewBox do desenho).
    SIZES = {
      building: [ 60, 58 ], tower: [ 42, 74 ], warehouse: [ 84, 56 ], shop: [ 56, 54 ], container: [ 50, 28 ],
      skatepark: [ 112, 76 ], halfpipe: [ 72, 46 ], funbox: [ 52, 36 ], kicker: [ 26, 22 ],
      graffiti_wall: [ 58, 28 ], dumpster: [ 34, 24 ], planter: [ 44, 30 ], ledge: [ 40, 18 ], rail: [ 44, 14 ],
      stairs: [ 36, 40 ], tree: [ 26, 28 ], bin: [ 12, 16 ], cone: [ 10, 12 ], car: [ 30, 14 ], boat: [ 42, 18 ],
      lawn: [ 72, 46 ], plaza: [ 84, 52 ], parking: [ 80, 44 ], court: [ 76, 46 ],
      stain: [ 30, 14 ], crack: [ 28, 18 ], litter: [ 18, 10 ], puddle: [ 26, 12 ], pothole: [ 14, 9 ], road_patch: [ 20, 13 ]
    }.freeze

    LAYERS = {
      lawn: :patch, plaza: :patch, parking: :patch, court: :patch,
      stain: :decal, crack: :decal, litter: :decal, puddle: :decal,
      pothole: :road, road_patch: :road, boat: :water
    }.freeze

    # Uma peça não encosta nas da própria camada nem nas listadas aqui. Árvores e
    # obstáculos podem ficar em cima do gramado e da praça; a sujeira, não.
    BLOCKED_BY = {
      patch: %i[patch decal], object: %i[object], decal: %i[decal object patch], road: %i[road], water: %i[water]
    }.freeze

    # O que cada ilha ganha, em rodízio pelos módulos: [peça, quantas, onde].
    # coast: na beira da ilha · ground: onde houver espaço · street: estacionada na
    # rua do módulo · road: na própria rua da trilha.
    THEMES = [
      # Bairro: loja de skate, prédios grafitados e uma pracinha com ledge.
      [ [ :plaza, 1, :ground ], [ :lawn, 1, :ground ], [ :parking, 1, :ground ], [ :shop, 1, :coast ],
        [ :warehouse, 1, :ground ], [ :building, 6, :coast ], [ :tower, 2, :coast ], [ :graffiti_wall, 2, :ground ],
        [ :ledge, 1, :ground ], [ :kicker, 1, :ground ], [ :dumpster, 1, :ground ], [ :tree, 6, :ground ],
        [ :bin, 2, :ground ], [ :cone, 4, :ground ] ],
      # Praça: gramados, quadra, árvores e uma pista pequena.
      [ [ :lawn, 4, :ground ], [ :plaza, 1, :ground ], [ :court, 1, :ground ], [ :skatepark, 1, :ground ],
        [ :shop, 1, :coast ], [ :building, 5, :coast ], [ :tower, 2, :coast ], [ :planter, 3, :ground ],
        [ :ledge, 2, :ground ], [ :rail, 1, :ground ], [ :tree, 14, :ground ], [ :bin, 3, :ground ], [ :cone, 3, :ground ] ],
      # Transição: bowl, mini rampa, funbox e rampinhas.
      [ [ :plaza, 2, :ground ], [ :skatepark, 2, :ground ], [ :halfpipe, 2, :ground ], [ :funbox, 1, :ground ],
        [ :kicker, 2, :ground ], [ :warehouse, 1, :ground ], [ :building, 4, :coast ], [ :graffiti_wall, 2, :ground ],
        [ :tree, 5, :ground ], [ :bin, 2, :ground ], [ :cone, 4, :ground ] ],
      # Pico de rua: escadas, corrimãos, ledges e o porto.
      [ [ :parking, 1, :ground ], [ :plaza, 1, :ground ], [ :stairs, 2, :ground ], [ :warehouse, 1, :ground ],
        [ :building, 6, :coast ], [ :tower, 2, :coast ], [ :container, 2, :coast ], [ :funbox, 1, :ground ],
        [ :graffiti_wall, 3, :ground ], [ :ledge, 3, :ground ], [ :rail, 3, :ground ], [ :kicker, 1, :ground ],
        [ :dumpster, 1, :ground ], [ :tree, 3, :ground ], [ :bin, 2, :ground ], [ :cone, 5, :ground ] ]
    ].freeze

    # A rua de verdade, que toda ilha tem.
    STREET_LIFE = [
      [ :car, 2, :street ], [ :pothole, 2, :road ], [ :road_patch, 2, :road ], [ :stain, 4, :ground ],
      [ :crack, 4, :ground ], [ :litter, 5, :ground ], [ :puddle, 1, :ground ]
    ].freeze

    # Depois do tema, o espaço que sobra vira cidade: prédios, praças e árvores até não
    # caber mais (o chão cinza vazio deixava o mapa sem graça).
    FILL = [
      [ :building, :coast ], [ :tower, :coast ], [ :warehouse, :ground ], [ :building, :ground ],
      [ :lawn, :ground ], [ :plaza, :ground ], [ :tree, :ground ], [ :planter, :ground ], [ :tree, :ground ],
      [ :graffiti_wall, :ground ], [ :tree, :ground ], [ :kicker, :ground ]
    ].freeze
    FILL_ROUNDS = 10

    BUILDINGS  = [ %w[#c96a55 #8c4434], %w[#5f8fbf #3d6189], %w[#d6a548 #976f22], %w[#7fa266 #557341],
                   %w[#9a7bbd #6a518a], %w[#a9a49c #6f6b64], %w[#d27d9b #94506a] ].freeze
    TAGS       = %w[#ff4fa3 #2ee6d6 #c6ff3d #ffb800 #fd591e #8f7bff #ffffff].freeze
    CARS       = %w[#e8463c #3b8cff #f2c94c #e3e2e6 #30d158 #8f7bff].freeze
    CONTAINERS = %w[#c0392b #2f6fd6 #e67e22 #16a085].freeze

    ROAD_CLEARANCE = 20 # metade da rua com a calçada (18) e uma folga
    BUCKET = 24         # os pontos da rua ficam agrupados por faixas de altura
    TRIES  = 40

    CACHE = Concurrent::Map.new

    # O cenário só depende da trilha (não do progresso): é calculado uma vez e guardado.
    def self.for(layout)
      CACHE.clear if CACHE.size > 32
      CACHE.compute_if_absent(signature(layout)) { new(layout).pieces }
    end

    def self.signature(layout)
      [ layout.height,
        layout.nodes.map { |node| [ node.maneuver.code, node.maneuver.name, node.point, node.label_side ] },
        layout.districts.map { |district| [ district.learning_module.code, district.learning_module.name ] } ].hash
    end

    def initialize(layout)
      @layout  = layout
      @samples = layout.road_samples
      @road    = @samples.group_by { |_x, y| (y / BUCKET).floor }
      @blocks  = node_boxes + label_boxes + sign_boxes + flag_boxes
      @streets = layout.districts.map { |district| Box.new(x: 0, y: district.y - 17, width: MAP_WIDTH, height: 34) }
      @pieces  = []
    end

    # Peças na ordem de desenho: quem está mais embaixo no mapa fica por cima.
    def pieces
      @layout.islands.each { |island| furnish(island) }
      moor_boats
      @pieces.sort_by { |piece| piece.box.bottom }
    end

    private

    def furnish(island)
      random   = Random.new(island.index * 101 + 7)
      district = @layout.districts.find { |candidate| candidate.y.between?(island.top, island.bottom) }
      road     = @samples.select { |_x, y| y.between?(island.top + 12, island.bottom - 12) }
      area     = Box.new(x: 0, y: island.top - 40, width: MAP_WIDTH, height: island.bottom - island.top + 80)
      @nearby  = @blocks.select { |block| block.overlaps?(area) }
      @local   = []
      put = ->(kind, zone) { place(kind, random) { |width, height| spot(zone, width, height, island, district, road, random) } }

      (THEMES[island.index % THEMES.size] + STREET_LIFE).each { |kind, count, zone| count.times { put.(kind, zone) } }
      FILL_ROUNDS.times { break if FILL.map { |kind, zone| put.(kind, zone) }.none? }
    end

    # Barcos nos canais, longe da ponte.
    def moor_boats
      @layout.canals.each_with_index do |(above, below), index|
        random  = Random.new(index * 53 + 11)
        top     = above + WALL + 6
        bottom  = below - 6 - SIZES[:boat].last
        @nearby = []
        @local  = []
        next if bottom < top

        2.times do
          place(:boat, random) do |width, height|
            Box.new(x: random.rand(8.0..(MAP_WIDTH - 8 - width)), y: random.rand(top..bottom), width: width, height: height)
          end
        end
      end
    end

    # Tenta alguns lugares sorteados e fica com o primeiro livre (devolve nil se não couber).
    def place(kind, random)
      width, height = SIZES.fetch(kind)
      layer = LAYERS.fetch(kind, :object)

      TRIES.times do
        box = yield(width, height) or return
        next unless free?(box, layer, kind)

        piece = Piece.new(kind: kind, layer: layer, box: box.with(x: box.x.round(1), y: box.y.round(1)),
                          style: style_for(kind, random))
        @local << piece
        return @pieces << piece
      end
      nil
    end

    def spot(zone, width, height, island, district, road, random)
      left, right = island.left + 8, island.right - 8 - width
      top, bottom = island.top + 8, island.bottom - 4 - height
      return if right < left || bottom < top

      case zone
      when :coast
        x = random.rand < 0.5 ? island.left + 7 : island.right - 7 - width
        Box.new(x: x, y: random.rand(top..bottom), width: width, height: height)
      when :ground
        Box.new(x: random.rand(left..right), y: random.rand(top..bottom), width: width, height: height)
      when :street
        return unless district

        lane = random.rand < 0.5 ? district.y - 14.5 : district.y + 14.5 - height
        Box.new(x: random.rand(left..right), y: lane, width: width, height: height)
      when :road
        return if road.empty?

        x, y = road.sample(random: random)
        Box.new(x: x - width / 2.0 + random.rand(-3.0..3.0), y: y - height / 2.0, width: width, height: height)
      end
    end

    def free?(box, layer, kind)
      area = box.grow(layer == :object ? 3 : 1)
      return false if layer != :road && near_road?(area, layer == :water ? 26 : ROAD_CLEARANCE)
      return false if @nearby.any? { |block| block.overlaps?(area) }
      return false if layer.in?(%i[object patch]) && kind != :car && @streets.any? { |street| street.overlaps?(area) }

      @local.none? { |piece| BLOCKED_BY[layer].include?(piece.layer) && piece.box.overlaps?(area) }
    end

    def near_road?(box, clearance)
      area = box.grow(clearance)
      ((area.y / BUCKET).floor..(area.bottom / BUCKET).floor).any? do |bucket|
        @road.fetch(bucket, []).any? { |x, y| x.between?(area.x, area.right) && y.between?(area.y, area.bottom) }
      end
    end

    def style_for(kind, random)
      tag_a, tag_b = TAGS.sample(2, random: random)
      case kind
      when :building, :tower, :warehouse
        roof, wall = BUILDINGS.sample(random: random)
        "--roof: #{roof}; --wall: #{wall}; --tag-a: #{tag_a}; --tag-b: #{tag_b}"
      when :shop
        roof, wall = BUILDINGS.sample(random: random)
        "--roof: #{roof}; --wall: #{wall}; --paint: #{CARS.sample(random: random)}; --tag-a: #{tag_a}; --tag-b: #{tag_b}"
      when :car then "--paint: #{CARS.sample(random: random)}"
      when :container then "--paint: #{CONTAINERS.sample(random: random)}; --tag-a: #{tag_a}"
      when :skatepark, :halfpipe, :funbox, :graffiti_wall, :dumpster then "--tag-a: #{tag_a}; --tag-b: #{tag_b}"
      end
    end

    # O que o cenário não pode cobrir: bolinhas, nomes das tarefas, placas e bandeiras.
    def node_boxes = @layout.nodes.map { |node| around(node.point.svg_x, node.point.y, 56, 56) }

    def flag_boxes
      [ around(@layout.start.svg_x, @layout.start.y, 112, 36), around(@layout.finish.svg_x, @layout.finish.y, 116, 36) ]
    end

    # Tamanho aproximado do nome da tarefa: o texto quebra a linha em 40% do mapa.
    def label_boxes
      @layout.nodes.map do |node|
        natural = "#{node.maneuver.code} · #{node.maneuver.name}".length * 6.6
        width   = [ natural, 126 ].min + 22
        height  = (natural / 126).ceil.clamp(1, 3) * 12.5 + 12
        x = node.label_side == :right ? node.point.svg_x + 30 : node.point.svg_x - 30 - width
        Box.new(x: x, y: node.point.y - height / 2, width: width, height: height).grow(6)
      end
    end

    def sign_boxes
      @layout.districts.map do |district|
        width = "Módulo #{district.learning_module.code} · #{district.learning_module.name}".length * 6.8 + 28
        x = district.sign_side == :left ? 10 : MAP_WIDTH - 10 - width
        Box.new(x: x, y: district.y - 13, width: width, height: 26).grow(4)
      end
    end

    def around(x, y, width, height) = Box.new(x: x - width / 2.0, y: y - height / 2.0, width: width, height: height)
  end
end
