# Skate

Aplicacao web para ensinar skate por meio de uma trilha progressiva de modulos, diagnostico inicial, sessoes de treino e acompanhamento de progresso.

O projeto foi desenvolvido com Ruby on Rails, SQLite, Tailwind CSS, Hotwire, Stimulus e importmap.

## Requisitos

- Ruby `3.4.1` (definido em `.ruby-version`)
- Bundler
- SQLite 3
- ffmpeg (com ffprobe): limpa a localizacao (GPS) e os outros metadados dos videos antes de guardar. Sem ele, nenhum video e aceito.
  - Windows: `winget install Gyan.FFmpeg` (depois abra um terminal novo)
  - macOS: `brew install ffmpeg`
  - Linux: `sudo apt install ffmpeg`
- Node.js nao e necessario para o fluxo padrao de desenvolvimento

Confira as versoes instaladas:

```bash
ruby -v
bundle -v
sqlite3 --version
ffmpeg -version
```

Videos guardados antes da limpeza existir: rode `bin/rails videos:limpar` uma vez.

## Instalacao

Clone o repositorio e entre na pasta do projeto:

```bash
git clone URL_DO_REPOSITORIO
cd skate
```

Instale as gems:

```bash
bundle install
```

Prepare o banco, execute as migrations e carregue os dados iniciais da trilha:

```bash
bin/rails db:prepare
bin/rails db:seed
```

O seed cria os modulos, manobras e passos de instrucao necessarios para usar o fluxo completo do diagnostico e da trilha.

## Executando em desenvolvimento

Inicie o servidor Rails e o watcher do Tailwind com:

```bash
bin/dev
```

Abra [http://localhost:3000](http://localhost:3000) no navegador.

Para iniciar somente o servidor Rails:

```bash
bin/rails server
```

No Windows, pelo PowerShell (o terminal padrao do VS Code), ponha `ruby` na frente:
sem isso o Windows pergunta "com qual aplicativo abrir 'rails'" e nada acontece.

```powershell
ruby bin/rails server
```

### Abrindo no celular (mesma rede Wi-Fi)

Ligue o servidor aberto para a rede de casa:

```powershell
ruby bin/rails server -b 0.0.0.0
```

No computador continua `http://localhost:3000`. No celular, conectado no mesmo Wi-Fi
(no 4G/5G nao funciona), abra `http://<IPv4 do computador>:3000`. O IPv4 aparece no
PowerShell com `ipconfig` (linha "Endereco IPv4" do Wi-Fi, algo como `192.168.0.8`).
Na primeira vez, o Windows pode pedir para liberar o Ruby no firewall: aceite.

Pelo `http://` a camera dentro do app, a localizacao (Picos) e a pagina "Sem sinal" nao
funcionam: o celular so libera esses recursos em sites `https://`.

## Testes

Execute a suite de testes com:

```bash
bin/rails test
```

Verifique a sintaxe Ruby de um arquivo especifico:

```bash
ruby -c app/controllers/application_controller.rb
```

## Estrutura principal

```text
app/controllers/     Controllers e fluxos HTTP
app/models/          Entidades e regras basicas do dominio
app/services/        Progressao da trilha e planejamento do diagnostico
app/views/           Templates ERB e partials
app/javascript/      Controllers Stimulus
app/assets/tailwind/ Tokens e componentes visuais
db/migrate/          Migrations do banco
db/seeds.rb          Dados iniciais da trilha
test/                Testes automatizados
```

## Fluxo da aplicacao

1. A pessoa informa o ano de nascimento.
2. O diagnostico identifica nivel, dificuldades e setup.
3. O `DiagnosisPlanner` resume o diagnostico e recomenda drills; a trilha comeca na 0.1 para todo mundo.
4. O `TrackProgression` controla nos disponiveis, bloqueados, pulados e concluidos. A seta laranja do mapa marca a tarefa atual.
5. A pessoa treina, registra o resultado e envia o video para a fila do mentor.
6. A tarefa so e concluida com a devolutiva do mentor; ai a seta avanca. Sem devolutiva, a pessoa pode usar "Avancar para a proxima tarefa" (com aviso), e a tarefa fica pulada, sem check.

Principais rotas:

| Tela | Rota |
| --- | --- |
| Pagina inicial | `/` |
| Cadastro / Entrar | `/cadastro`, `/entrar` |
| Recuperar senha | `/recuperar-senha` |
| Minha conta | `/conta` |
| Gravar video | `/gravar` |
| Zine (videos e analises) | `/zine` |
| Mapa de picos (Google Maps) | `/picos` |
| Link de um role para os amigos (publico) | `/role/:token` |
| Idade e seguranca | `/comecar/idade` |
| Diagnostico | `/comecar/diagnostico?step=level` |
| Plano do diagnostico | `/comecar/diagnostico/plano` |
| Trilha | `/trilha` |
| Manobras | `/manobras/:slug` |
| Sessoes de treino | `/manobras/:slug/treinos/new` |
| Agenda | `/agenda/new` |
| Ajuda | `/ajuda` |

## Docker

O `Dockerfile` e preparado para producao. Para criar a imagem:

```bash
docker build -t skate .
```

Para executar localmente, forneca uma chave mestre Rails valida:

```bash
docker run --rm -p 3000:80 \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  skate
```

## Variaveis e credenciais

Nao versione arquivos com segredos. Em producao, configure `RAILS_MASTER_KEY` e as credenciais necessarias no ambiente de execucao.

### Google Maps (mapa de picos)

O mapa de `/picos` usa a Maps JavaScript API do Google. Sem a chave, a pagina funciona, mas mostra o aviso "O mapa do Google nao carregou" no lugar do mapa.

1. Em [console.cloud.google.com](https://console.cloud.google.com), crie um projeto, ative a **Maps JavaScript API** e cadastre uma conta de faturamento (o Google pede cartao; ha uma cota gratuita mensal, confira os valores atuais).
2. Em **Credenciais**, crie uma chave de API e **restrinja** (a chave vai para o navegador, e assim no Google Maps):
   - Restricao de aplicativo: **Sites**, com `http://localhost:3000/*`, `http://127.0.0.1:3000/*` e, depois, `https://SEU-DOMINIO/*`.
   - Restricao de API: so a **Maps JavaScript API**.
3. Defina a variavel `GOOGLE_MAPS_API_KEY` antes de ligar o servidor. No Windows: `setx GOOGLE_MAPS_API_KEY "SUA_CHAVE"` e abra um terminal novo (ou feche e abra o VS Code).
4. Em producao, crie um **Map ID** (Gerenciamento de mapas, tipo JavaScript) e defina `GOOGLE_MAPS_MAP_ID`. Em desenvolvimento o app usa o `DEMO_MAP_ID` do Google.

Os picos fixos do mapa ficam em `config/picos.yml` (nome, tipo, descricao, lat e lng). O teste `test/models/spot_test.rb` confere o arquivo.

A localizacao do aparelho so funciona em `https` ou em `localhost`: abrindo pelo IP da rede no celular (`http://192.168...`), o navegador bloqueia e a pagina mostra como liberar.

## Documentacao das funcionalidades

- [Autenticacao, pagina Gravar e aba Zine](docs/autenticacao-gravar-zine.md)

## Estado atual

- O envio de codigo de acesso ainda e representado nos logs.
- O video do treino vai para a fila do mentor (resposta prometida em ate 48h); ainda nao ha analise automatica nem tela para o mentor responder. Ligar a analise automatica: `config.x.stance.automatic_review` + `Ai::FallAnalyzer#call`.
- A fila offline esta modelada, mas o service worker completo ainda pode ser evoluido.
- A trilha e cadastrada por `db/seeds.rb`.

## Licenca

Nenhuma licenca foi definida para este projeto.
