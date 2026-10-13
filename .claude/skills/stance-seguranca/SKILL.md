---
name: stance-seguranca
description: Checklist de segurança do app Stance (Rails 8) e como rodar as mesmas verificações do CI do GitHub. Use sempre que mexer em login/cadastro/senha, controllers, rotas, dados de usuário, uploads de vídeo, formulários, redirecionamentos, logs, credenciais/segredos, variáveis de ambiente, Gemfile/gems ou importmap — e quando o usuário pedir revisão de segurança, "está seguro?", "pode publicar?" ou antes de abrir um Pull Request. Inclui menores de idade (13+) e vídeos pessoais, então privacidade importa.
---

# Segurança no Stance

O app guarda e-mail/telefone, senha, ano de nascimento e **vídeos pessoais de
skatistas a partir de 13 anos**. Um vazamento entre usuários é o pior cenário possível.
Revise a mudança pelo checklist abaixo e rode as verificações automáticas antes do commit.

## Checklist por tipo de mudança

**Controller ou rota nova**
- Login já é obrigatório por padrão (`Authentication` em `ApplicationController`).
  Libere páginas públicas só com `allow_unauthenticated_access only: [...]`, nunca sem `only`
  (exceto telas de acesso como login/recuperação, que já são públicas de propósito).
- Telas do app de verdade também pedem `before_action :require_age_gate` (e
  `:require_diagnosis` quando dependem da trilha), como em `RecordingsController`.
- Busque registros **a partir do usuário**: `current_user.training_sessions.find(params[:id])`,
  nunca `TrainingSession.find(params[:id])`. Isso é o que impede alguém de ver o vídeo
  de outra pessoa trocando o número na URL. Inclua teste de isolamento (ver `zine_test.rb`).
- Parâmetros com `params.require(:x).permit(...)` ou `params.fetch(:x, {}).permit(...)`.
  Nunca permita `user_id`, `status`, `registered_at` ou similares vindos do formulário.

**Área do mentor (vê vídeos de todos os aprendizes, inclusive menores)**
- Ninguém vira mentor sozinho: o cadastro como "Mentor" só cria um pedido
  (`User#request_mentor`, exige 18+), e só um **administrador** aprova, recusa ou remove,
  em `/mentor/pedidos` (`require_admin`). Mentor não aprova mentor. Administrador só se
  cria pelo terminal (`bin/rails "admin:promover[...]"`). Nunca libere `role` por formulário.
- Toda tela de mentor herda de `Mentor::BaseController` (404 para quem não é mentor).
  O administrador tem todas as funções de mentor.
- Apagar vídeo: só o dono e o administrador (`TrainingSession#clip_deletable_by?`).
- Justificativas de parada da ofensiva (`StreakJustification`) podem ter dado de saúde:
  só mentores leem, com o contato mascarado, e ninguém avalia a própria. A sessão da
  ofensiva (`SkateSession`) guarda só o dia, nunca o lugar do rolê.
- O mentor vê o contato do aprendiz mascarado (`masked_contact`) e não vê as anotações
  pessoais do treino. Mantenha esse mínimo ao criar telas novas de mentor.
- **Chat** (`Conversation`/`Message`): uma conversa por aprendiz, da **equipe** de
  mentores (todos leem e respondem; nada de conversa privada entre um adulto e um
  aprendiz). `Message::CONTACT_PATTERNS` barra telefone, e-mail, link e @ de rede
  social; não afrouxe. O texto das mensagens não vai para o log (`:body` em
  `filter_parameter_logging.rb`). Mentor não abre chat com mentor (`User.role_learner.find`).

**Formulários e redirecionamentos**
- `form_with` já inclui o token CSRF; não desligue `protect_from_forgery`.
- `redirect_to ..., allow_other_host: true` só com URL montada no servidor (como o
  WhatsApp de suporte), nunca com URL vinda de parâmetro (redirecionamento aberto).
- Redirect para outro site ou `render` de sucesso após POST → o formulário precisa de
  `data: { turbo: false }`, senão o botão "não faz nada".

**Login, senha e códigos**
- Ações de cadastro, login e recuperação têm `rate_limit to: 10, within: 3.minutes`;
  mantenha em ações novas desse tipo.
- Mensagens de login/recuperação não podem revelar se a conta existe.
- Ao trocar senha ou identidade: `reset_session` (já feito em `start_session_for`/`sign_out`).
- O código de recuperação hoje **só é escrito no log** (`AccessCodeDelivery`). Isso não
  pode ir para produção: o envio real por e-mail/WhatsApp é pendência conhecida.

**Localização e rolês (mapa de Picos)**
- A localização do aparelho só centraliza o mapa no navegador (`spots_map_controller.js`):
  nunca envie ao servidor nem guarde. O que fica no banco é só o lugar que a pessoa
  escolheu para o rolê (`Meetup`), e ele é apagado depois do horário de fim.
- O link para os amigos (`/role/:token`) é público: mostra lugar, dia, horário e recado,
  nunca nome, e-mail ou telefone de quem marcou. Rolês não aparecem para outros usuários
  no mapa. Não crie lista pública de rolês: há menores de idade (13+) no app.
- A chave do Google Maps vai para o navegador; a proteção é a restrição por endereço no
  Google Cloud (README). Nunca coloque no código: use `GOOGLE_MAPS_API_KEY`.

**Uploads (vídeos)**
- Validação sempre no servidor (`TrainingSession#validate_clip`): tipo pelo conteúdo
  (não pela extensão), tamanho (40 MB) e duração. O navegador só dá feedback rápido.
- Todo vídeo passa pelo `ClipSanitizer` antes de ser guardado (o `TrainingSession#clip=`
  chama): o ffmpeg tira localização (GPS), data, aparelho e o nome original do arquivo.
  Não guarde vídeo por outro caminho (ex.: `ActiveStorage::Blob.create_and_upload!`).
  Sem ffmpeg o vídeo é recusado, de propósito. Vídeos antigos: `bin/rails videos:limpar`.
- O service worker do app instalado (`pwa/service-worker.js`) guarda no celular só o
  visual (`/assets`) e a página Sem sinal. Nunca guarde páginas (têm dados pessoais),
  vídeos (`/clips`) nem respostas de formulário: o celular pode ser de outra pessoa.
- Vídeo só abre por `clip_path` (`ClipsController`: login, permissão e registro de quem
  assistiu). As rotas públicas do Active Storage estão desligadas; não religue nem use
  `url_for(clip)`/`rails_blob_path`, que davam link sem login e sem prazo.
- Testes de vídeo precisam do ffmpeg e do ffprobe instalados (o CI instala).

**Views**
- O ERB já escapa o texto. Evite `raw`, `html_safe` e `<%==` com qualquer coisa que
  venha do usuário; se precisar de HTML, use `sanitize`.

**Banco**
- Consultas com hash ou placeholders (`where(email: valor)`, `where("x = ?", valor)`),
  nunca interpolando texto do usuário na string SQL.

**Segredos**
- `config/master.key` e `.env*` são ignorados pelo Git (ver `.gitignore`); mantenha
  assim. A chave mestra não está nesta máquina: peça ao parceiro por um canal privado,
  nunca por commit.
- Chaves de serviços (S3, WhatsApp, IA) vão em credenciais do Rails ou variáveis de
  ambiente, nunca no código.
- `filter_parameter_logging.rb` filtra senha, e-mail e token dos logs; ao criar campos
  sensíveis novos, inclua-os lá.

**Gems e JavaScript**
- Gem nova: confira se é mantida e popular; prefira o que o Rails já traz.
- Atualizações do Dependabot: revise uma de cada vez e rode os testes.

## Verificações automáticas (iguais ao CI)

```bash
bin/brakeman --no-pager                  # falhas de segurança no código
bin/bundler-audit                        # gems com falhas conhecidas
bin/importmap audit                      # pacotes JavaScript vulneráveis
bin/rubocop                              # estilo (o CI falha se houver ofensas)
bin/rails db:test:prepare test           # testes
bin/rails db:test:prepare test:system    # testes de navegador (pasta test/system)
```

Todas passavam em 04/10/2026, sem nenhum alerta. Para manter assim:
- A Brakeman reprova com **qualquer** alerta, mesmo fraco. Corrija a causa; use
  `config/brakeman.ignore` só para falso positivo comprovado, com nota explicando.
- `bin/brakeman` usa `--ensure-latest`: quando sair uma versão nova da Brakeman, ele volta
  a reprovar até a gem ser atualizada (`bundle update brakeman --conservative` ou o Pull
  Request do Dependabot). Não é falha do código.
- `bin/bundler-audit` baixa a base de falhas conhecidas na primeira vez (precisa de
  internet). Se apontar uma gem, atualize só ela (`bundle update <gem> --conservative`)
  e rode os testes.
- `test/system` ainda só tem `.keep`: a etapa de testes de navegador do CI passa, mas não
  testa nada até alguém escrever testes ali.

## Como relatar

Liste os achados do mais grave para o menos grave, cada um com: onde está
(`arquivo:linha`), o que um atacante conseguiria fazer, e a correção sugerida. Diga
também o que foi verificado e estava certo, para o usuário saber o que ficou coberto.
