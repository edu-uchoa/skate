# Skate

Aplicacao web para ensinar skate por meio de uma trilha progressiva de modulos, diagnostico inicial, sessoes de treino e acompanhamento de progresso.

O projeto foi desenvolvido com Ruby on Rails, SQLite, Tailwind CSS, Hotwire, Stimulus e importmap.

## Requisitos

- Ruby `3.4.1` (definido em `.ruby-version`)
- Bundler
- SQLite 3
- Node.js nao e necessario para o fluxo padrao de desenvolvimento

Confira as versoes instaladas:

```bash
ruby -v
bundle -v
sqlite3 --version
```

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
3. O `DiagnosisPlanner` define o ponto de entrada na trilha.
4. O `TrackProgression` controla nos disponiveis, bloqueados e concluidos.
5. A pessoa inicia sessoes de treino e registra o resultado.

Principais rotas:

| Tela | Rota |
| --- | --- |
| Pagina inicial | `/` |
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

## Estado atual

- O envio de codigo de acesso ainda e representado nos logs.
- A analise de video usa um analisador deterministico de demonstracao.
- A fila offline esta modelada, mas o service worker completo ainda pode ser evoluido.
- A trilha e cadastrada por `db/seeds.rb`.

## Licenca

Nenhuma licenca foi definida para este projeto.
