# Skate do perfil (users.board_options): o tipo de skate, que já vem com a sua
# estampa padrão, e as cores das rodas e dos trucks. O desenho fica em
# app/views/decks/_deck.html.erb: a lixa (em cima), a estampa com os trucks
# (embaixo) e o perfil (de lado), como nas fotos de loja; cada estampa fica em
# app/views/decks/prints/.
class Deck
  # Medidas num shape de 140 x 380 (centro em x = 70), na proporção de um skate de
  # verdade (comprimento perto de 4 vezes a largura).
  # outline: contorno visto de cima; span: onde ficam o bico e o rabo (y); trucks:
  # altura de cada truck; axle: meia largura do eixo; wheel: largura e altura das
  # rodas; veneer: a cor principal da estampa (aparece na lateral e no skate do avatar).
  Type = Data.define(:key, :label, :description, :print, :outline, :span, :trucks, :axle, :wheel, :veneer)
  Color = Data.define(:key, :label, :color)

  # Na ordem da tela: do mais comum para a rua até o clássico.
  TYPES = [
    Type.new("street", "Street", "Shape de dois bicos, cerca de 8\" de largura, com rodas pequenas e duras para manobrar na rua.",
             "Mandala dourada", "M28 72 Q28 20 70 20 Q112 20 112 72 L112 308 Q112 360 70 360 Q28 360 28 308 Z",
             [ 20, 360 ], [ 112, 268 ], 40, [ 13, 22 ], "#121214"),
    Type.new("bowl", "Bowl", "Mais largo (8,5\" ou mais), com rodas maiores para ganhar velocidade nas transições.",
             "Monstro verde", "M25 76 Q25 18 70 18 Q115 18 115 76 L115 304 Q115 362 70 362 Q25 362 25 304 Z",
             [ 18, 362 ], [ 114, 266 ], 42, [ 14, 25 ], "#2fd04e"),
    Type.new("new_school", "New school", "O shape moderno de dois bicos, um pouco mais largo (8,25\"). Serve para rua e pista.",
             "Grafite", "M26.5 66 Q27 19 70 19 Q113 19 113.5 66 L113.5 314 Q113 361 70 361 Q27 361 26.5 314 Z",
             [ 19, 361 ], [ 113, 267 ], 41, [ 13, 23 ], "#6f7178"),
    Type.new("old_school", "Old school", "Largo (9,5\" a 10\"), com bico largo e arredondado e rabo mais estreito. Rodas grandes e macias, estilo anos 80.",
             "Caveira e punhal",
             "M70 30 C98 30 120 50 121 92 L122 220 C122 262 116 300 112 326 C110 342 104 350 96 350 L44 350 " \
             "C36 350 30 342 28 326 C24 300 18 262 18 220 L19 92 C20 50 42 30 70 30 Z",
             [ 30, 350 ], [ 116, 268 ], 46, [ 16, 27 ], "#c9ccd1")
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

  # Cores do desenho (e do skate na mão do avatar): rodas, trucks e a cor da estampa.
  def css_variables = [ *COLOR_VARS.map { |part, var| "#{var}: #{choice(part).color};" }, "--deck-veneer: #{type.veneer};" ].join(" ")
end
