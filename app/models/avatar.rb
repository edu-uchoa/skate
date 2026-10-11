# Avatar de skatista do perfil (users.avatar_options).
#
# Cada parte tem uma lista fechada de opções; o que vier do formulário fora da
# lista volta para o padrão. O desenho fica em app/views/avatars/_avatar.html.erb.
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
      Option.new("raspado", "Raspado"), Option.new("curto", "Curto"), Option.new("cacheado", "Cacheado"),
      Option.new("black-power", "Black power"), Option.new("moicano", "Moicano"), Option.new("coque", "Coque"),
      Option.new("rabo", "Rabo de cavalo"), Option.new("longo", "Longo"), Option.new("trancas", "Tranças")
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
    top: [
      Option.new("camiseta", "Camiseta"), Option.new("moletom", "Moletom"), Option.new("xadrez", "Camisa xadrez"),
      Option.new("regata", "Regata"), Option.new("jaqueta", "Jaqueta")
    ],
    top_color: [
      Option.new("preto", "Preto", "#26272c"), Option.new("branco", "Branco", "#e9e6df"),
      Option.new("amarelo", "Amarelo", "#ffb800"), Option.new("laranja", "Laranja", "#fd591e"),
      Option.new("azul", "Azul", "#2f6fd6"), Option.new("verde", "Verde", "#2e9e5b"),
      Option.new("vermelho", "Vermelho", "#d64545")
    ],
    bottom: [ Option.new("jeans", "Calça jeans"), Option.new("cargo", "Calça cargo"), Option.new("bermuda", "Bermuda") ],
    socks: [
      Option.new("curta", "Curta"), Option.new("branca", "Branca cano alto"),
      Option.new("listrada", "Listrada"), Option.new("amarela", "Amarela")
    ],
    shoes: [
      Option.new("cano-baixo-preto", "Cano baixo preto", "#1f1f23", "#e9e6df"),
      Option.new("cano-alto-branco", "Cano alto branco", "#e9e6df", "#c9c3b8"),
      Option.new("slip-on-xadrez", "Slip-on xadrez", "#1f1f23", "#e9e6df"),
      Option.new("cano-baixo-amarelo", "Cano baixo amarelo", "#ffb800", "#e9e6df")
    ],
    head: [
      Option.new("capacete-amarelo", "Capacete amarelo", "#ffb800"), Option.new("capacete-preto", "Capacete preto", "#2a2b30"),
      Option.new("bone", "Boné"), Option.new("aba-reta", "Aba reta"), Option.new("gorro", "Gorro"),
      Option.new("nenhum", "Nada")
    ]
  }.freeze

  # Começa de capacete: no Stance, segurança vem primeiro.
  DEFAULTS = {
    base: "feminino", skin: "3", vitiligo: false, eyes: "castanho", hair: "longo", hair_color: "preto",
    beard: "nenhuma", top: "moletom", top_color: "amarelo", bottom: "jeans", socks: "branca",
    shoes: "cano-baixo-preto", head: "capacete-amarelo"
  }.freeze

  # Grupos do editor, na ordem da tela.
  GROUPS = {
    base: "Avatar", skin: "Cor da pele", eyes: "Cor dos olhos", hair: "Cabelo", hair_color: "Cor do cabelo",
    beard: "Barba", top: "Roupa", top_color: "Cor da roupa", bottom: "Calça", socks: "Meias", shoes: "Tênis",
    head: "Boné ou capacete"
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
