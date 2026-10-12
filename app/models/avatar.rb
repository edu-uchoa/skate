# Avatar de skatista do perfil (users.avatar_options).
#
# Cada parte tem uma lista fechada de opções; o que vier do formulário fora da
# lista volta para o padrão (inclusive opções antigas que saíram, como "moicano").
# O desenho fica em app/views/avatars/_avatar.html.erb.
class Avatar
  Option = Data.define(:key, :label, :color, :shade) do
    def initialize(key:, label:, color: nil, shade: nil) = super
  end

  OPTIONS = {
    base: [ Option.new("feminino", "Feminino"), Option.new("masculino", "Masculino") ],
    skin: [
      Option.new("1", "Clara", "#f6d7c3", "#e2b89f"), Option.new("2", "Média clara", "#e8bc98", "#d29e78"),
      Option.new("3", "Morena", "#c98c62", "#ac714a"), Option.new("4", "Morena escura", "#a2663f", "#85502f"),
      Option.new("5", "Negra", "#7b4a2c", "#623a22"), Option.new("6", "Retinta", "#4f2f1c", "#3d2415")
    ],
    eyes: [
      Option.new("castanho-escuro", "Castanho escuro", "#3b2416"), Option.new("castanho", "Castanho", "#6b4423"),
      Option.new("mel", "Mel", "#a8742a"), Option.new("verde", "Verde", "#4f7d3b"),
      Option.new("azul", "Azul", "#3c78b5"), Option.new("cinza", "Cinza", "#7b8794")
    ],
    hair: [
      Option.new("raspado", "Raspado"), Option.new("curto", "Curto"), Option.new("ondulado", "Ondulado no ombro"),
      Option.new("cacheado", "Cacheado"), Option.new("black-power", "Black power"), Option.new("dreads", "Dreads"),
      Option.new("trancas", "Tranças"), Option.new("longo", "Longo liso")
    ],
    hair_color: [
      Option.new("preto", "Preto", "#1d1b1b"), Option.new("castanho", "Castanho", "#5a3825"),
      Option.new("loiro", "Loiro", "#d8b25c"), Option.new("ruivo", "Ruivo", "#b5502a"),
      Option.new("azul", "Azul", "#3b8cff"), Option.new("rosa", "Rosa", "#ff7eb6")
    ],
    beard: [
      Option.new("nenhuma", "Sem barba"), Option.new("rala", "Rala"), Option.new("bigode", "Bigode"),
      Option.new("cavanhaque", "Cavanhaque"), Option.new("cheia", "Cheia")
    ],
    # Roupas no estilo dos jogos de skate de hoje: tudo largo, sem marca nenhuma.
    top: [
      Option.new("moletom-capuz", "Moletom com capuz"), Option.new("moletom-caveira", "Moletom de caveira"),
      Option.new("camiseta-larga", "Camiseta larga"), Option.new("camiseta-estampa", "Camiseta estampada"),
      Option.new("xadrez", "Camisa xadrez")
    ],
    top_color: [
      Option.new("grafite", "Grafite", "#3a3b41"), Option.new("preto", "Preto", "#232428"),
      Option.new("verde-musgo", "Verde musgo", "#39463a"), Option.new("verde-limao", "Verde-limão", "#a9b84c"),
      Option.new("branco", "Branco", "#e9e6df"), Option.new("amarelo", "Amarelo", "#ffb800"),
      Option.new("laranja", "Laranja", "#fd591e"), Option.new("azul", "Azul", "#2f6fd6"),
      Option.new("vermelho", "Vermelho", "#c94040")
    ],
    bottom: [
      Option.new("jeans-claro", "Jeans claro largo"), Option.new("caqui", "Calça cáqui larga"),
      Option.new("camuflada", "Calça camuflada"), Option.new("cargo-preta", "Calça cargo preta"),
      Option.new("bermuda-preta", "Bermuda jeans preta")
    ],
    socks: [
      Option.new("curta", "Curta"), Option.new("branca", "Branca cano alto"),
      Option.new("listrada", "Listrada"), Option.new("preta", "Preta cano alto")
    ],
    # color: o cabedal (a parte de cima do tênis); shade: a sola.
    shoes: [
      Option.new("corrida", "Corrida grafite", "#46423f", "#ecebe6"),
      Option.new("classico", "Clássico preto e branco", "#1d1d21", "#ecebe6"),
      Option.new("camurca", "Camurça marrom", "#4b3427", "#e6dfcf"),
      Option.new("preto-caramelo", "Preto sola caramelo", "#222226", "#c47a3a"),
      Option.new("branco", "Branco", "#ecebe6", "#d9d4c8")
    ],
    head: [
      Option.new("capacete-amarelo", "Capacete amarelo", "#ffb800"), Option.new("capacete-preto", "Capacete preto", "#2a2b30"),
      Option.new("bone-para-tras", "Boné para trás"), Option.new("bone", "Boné"), Option.new("gorro", "Gorro"),
      Option.new("nenhum", "Nada")
    ]
  }.freeze

  # Começa de capacete: no Stance, segurança vem primeiro.
  DEFAULTS = {
    base: "feminino", skin: "3", vitiligo: false, eyes: "castanho", hair: "trancas", hair_color: "preto",
    beard: "nenhuma", top: "moletom-capuz", top_color: "verde-musgo", bottom: "caqui", socks: "branca",
    shoes: "camurca", head: "capacete-amarelo"
  }.freeze

  # Grupos do editor, na ordem da tela.
  GROUPS = {
    base: "Avatar", skin: "Cor da pele", eyes: "Cor dos olhos", hair: "Cabelo", hair_color: "Cor do cabelo",
    beard: "Barba", top: "Roupa", top_color: "Cor da roupa", bottom: "Calça ou bermuda", socks: "Meias",
    shoes: "Tênis", head: "Boné ou capacete"
  }.freeze

  # Cores que o desenho lê de variáveis CSS (a prévia troca na hora, sem recarregar).
  COLOR_VARS = { skin: %w[--av-skin --av-skin-shade], eyes: %w[--av-eyes], hair_color: %w[--av-hair], top_color: %w[--av-top] }.freeze

  attr_reader :settings

  def initialize(raw = nil)
    raw = (raw || {}).to_h.transform_keys(&:to_s)
    @settings = DEFAULTS.to_h do |part, default|
      value = raw[part.to_s]
      [ part, part == :vitiligo ? ActiveModel::Type::Boolean.new.cast(value) || false : valid(part, value) || default ]
    end
  end

  def [](part) = settings[part]
  def option(part) = OPTIONS[part].find { |option| option.key == settings[part] }
  def to_h = settings.transform_keys(&:to_s)

  # Variáveis CSS que pintam o desenho: style="--av-skin: ...;".
  def css_variables = COLOR_VARS.keys.flat_map { |part| self.class.color_vars(part, option(part)).map { |var, color| "#{var}: #{color};" } }.join(" ")

  # As cores de uma opção, por variável CSS ({ "--av-skin" => "#c98c62", ... }).
  def self.color_vars(part, option) = COLOR_VARS.fetch(part, []).zip([ option.color, option.shade ]).to_h.compact

  private

  def valid(part, value) = OPTIONS[part].find { |option| option.key == value.to_s }&.key
end
