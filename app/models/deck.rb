# Skate do perfil (users.board_options): o tipo de skate, que já vem com a sua
# estampa padrão, e as cores das rodas e dos trucks. O desenho fica em
# app/views/decks/_deck.html.erb (visto de baixo, com a estampa).
class Deck
  # outline: contorno do shape (viewBox 0 0 140 380); trucks: altura de cada truck;
  # wheel: largura e altura das rodas; axle: meia largura do eixo.
  Type = Data.define(:key, :label, :description, :print, :outline, :trucks, :axle, :wheel)
  Color = Data.define(:key, :label, :color)

  TYPES = [
    Type.new("street", "Street", "Shape de dois bicos, estreito (cerca de 8\"), com rodas pequenas e duras para manobrar na rua.",
             "Listras Stance", "M44 72 Q44 22 70 22 Q96 22 96 72 L96 308 Q96 358 70 358 Q44 358 44 308 Z",
             [ 96, 284 ], 33, [ 11, 20 ]),
    Type.new("new_school", "New school", "O shape moderno de dois bicos, um pouco mais largo (8,25\"). Serve para rua e pista.",
             "Geometria", "M41 68 Q41 24 70 24 Q99 24 99 68 L99 312 Q99 356 70 356 Q41 356 41 312 Z",
             [ 98, 282 ], 35, [ 12, 21 ]),
    Type.new("bowl", "Bowl", "Mais largo (8,5\" ou mais), com rodas maiores para ganhar velocidade nas transições.",
             "Piscina", "M37 80 Q37 18 70 18 Q103 18 103 80 L103 300 Q103 362 70 362 Q37 362 37 300 Z",
             [ 102, 278 ], 38, [ 13, 24 ]),
    Type.new("old_school", "Old school", "Largo (9,5\" a 10\"), com bico arredondado e rabo em V. Rodas grandes e macias, estilo anos 80.",
             "Chamas", "M40 62 Q42 18 70 16 Q98 18 100 62 L108 196 Q109 292 100 334 L84 362 L70 344 L56 362 L40 334 Q31 292 32 196 Z",
             [ 100, 276 ], 42, [ 15, 27 ])
  ].freeze

  WHEELS = [
    Color.new("branca", "Branca", "#f2efe6"), Color.new("amarela", "Amarela", "#ffd23f"),
    Color.new("laranja", "Laranja", "#fd7a1e"), Color.new("azul", "Azul", "#3b8cff"), Color.new("preta", "Preta", "#2a2b30")
  ].freeze

  TRUCKS = [ Color.new("prata", "Prata", "#b8bcc4"), Color.new("preto", "Preto", "#3a3b40"), Color.new("dourado", "Dourado", "#d4a72c") ].freeze

  DEFAULTS = { type: "street", wheels: "branca", trucks: "prata" }.freeze
  CHOICES  = { type: TYPES, wheels: WHEELS, trucks: TRUCKS }.freeze
  COLOR_VARS = { wheels: "--deck-wheels", trucks: "--deck-trucks" }.freeze

  attr_reader :settings

  def initialize(raw = nil)
    raw = (raw || {}).to_h.transform_keys(&:to_s)
    @settings = DEFAULTS.to_h { |part, default| [ part, CHOICES[part].find { |choice| choice.key == raw[part.to_s].to_s }&.key || default ] }
  end

  def [](part) = settings[part]
  def type = TYPES.find { |type| type.key == settings[:type] }
  def choice(part) = CHOICES[part].find { |choice| choice.key == settings[part] }
  def to_h = settings.transform_keys(&:to_s)

  def css_variables = COLOR_VARS.map { |part, var| "#{var}: #{choice(part).color};" }.join(" ")
end
