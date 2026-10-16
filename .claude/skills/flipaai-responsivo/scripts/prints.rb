# Tira prints de telas do FlipaAi no Edge sem janela (Selenium), com login opcional.
#
# Uso (com o servidor de teste rodando na porta 3001):
#   bundle exec ruby .claude/skills/flipaai-responsivo/scripts/prints.rb \
#     --email teste.prints@flipaai.dev --saida <pasta> --tamanhos celular,desktop /trilha /zine
#
# Para cada tamanho e caminho: mostra o status HTTP (200, 302 -> destino...), avisa se a
# página de erro do Rails apareceu e salva <pasta>/<tamanho>_<caminho>.png.
require "selenium-webdriver"
require "net/http"
require "optparse"
require "fileutils"

TAMANHOS = {
  "celular" => [ 390, 844, true ],   # iPhone comum
  "baixo"   => [ 390, 600, true ],   # celular com tela baixa / teclado aberto
  "longo"   => [ 390, 2400, true ],  # página inteira de uma vez (conteúdo longo)
  "desktop" => [ 1280, 760, false ]  # computador: o app aparece na moldura de 414px
}.freeze

opts = { base: "http://localhost:3001", senha: "senha1234", saida: "prints", tamanhos: %w[celular desktop] }
OptionParser.new do |o|
  o.on("--email EMAIL") { |v| opts[:email] = v }
  o.on("--senha SENHA") { |v| opts[:senha] = v }
  o.on("--saida PASTA") { |v| opts[:saida] = v }
  o.on("--base URL") { |v| opts[:base] = v }
  o.on("--tamanhos LISTA", "celular,baixo,longo,desktop") { |v| opts[:tamanhos] = v.split(",") }
end.parse!
# No Git Bash, "/trilha" chega como "C:/Program Files/Git/trilha": desfaz isso e aceita "trilha".
def normalizar(caminho)
  caminho = caminho.sub(%r{\A[A-Za-z]:/.*?/Git(?=/|\z)}, "")
  "/#{caminho.delete_prefix('/')}"
end

caminhos = (ARGV.empty? ? [ "/" ] : ARGV).map { |c| normalizar(c) }
FileUtils.mkdir_p(opts[:saida])

def navegador(largura, altura, celular)
  o = Selenium::WebDriver::Edge::Options.new
  o.add_argument("--headless=new")
  o.add_argument("--window-size=#{largura},#{altura}")
  o.add_emulation(device_metrics: { width: largura, height: altura, pixelRatio: 1, touch: true }) if celular
  Selenium::WebDriver.for(:edge, options: o)
end

def entrar(d, base, email, senha)
  d.navigate.to "#{base}/entrar/senha" # login com senha das contas de teste
  d.find_element(name: "session[contact]").send_keys(email)
  d.find_element(name: "session[password]").send_keys(senha)
  d.find_element(name: "session[password]").submit
  sleep 1.2
end

def status(d, base, caminho)
  cookie = d.manage.all_cookies.map { |c| "#{c[:name]}=#{c[:value]}" }.join("; ")
  uri = URI("#{base}#{caminho}")
  res = Net::HTTP.start(uri.host, uri.port) { |h| h.get(uri.request_uri, "Cookie" => cookie) }
  [ res.code, res["location"]&.sub(base, "") ].compact.join(" -> ")
end

opts[:tamanhos].each do |nome|
  largura, altura, celular = TAMANHOS.fetch(nome)
  d = navegador(largura, altura, celular)
  entrar(d, opts[:base], opts[:email], opts[:senha]) if opts[:email]

  caminhos.each do |caminho|
    st = status(d, opts[:base], caminho)
    d.navigate.to "#{opts[:base]}#{caminho}"
    sleep 1
    erro = d.title.include?("Exception") || d.page_source.include?("exception-message")
    arquivo = File.join(opts[:saida], "#{nome}_#{caminho == "/" ? "inicio" : caminho.gsub(/\W+/, "_").gsub(/^_|_$/, "")}.png")
    d.save_screenshot(arquivo)
    puts format("%-8s %-40s %-26s %s", nome, caminho, st, erro ? "ERRO NA PAGINA" : arquivo)
  end
  d.quit
end
