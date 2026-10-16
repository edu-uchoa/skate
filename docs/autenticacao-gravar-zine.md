# Autenticação, página Gravar e aba Zine

Este documento resume três funcionalidades adicionadas ao app: o acesso obrigatório com conta, a gravação/envio de vídeos de manobras e a aba Zine, que reúne os vídeos e o andamento da análise.

Tudo foi construído sobre a arquitetura existente: não há modelo novo de usuário, de sessão nem de vídeo. Os vídeos continuam sendo o `clip` de um `TrainingSession`, e a análise continua sendo o `AiReview`.

## Resumo rápido

| Funcionalidade | Rota | Onde fica o código |
| --- | --- | --- |
| Cadastro (só Google) | `/cadastro` | `AccountsController#new` |
| Login | `/entrar` | `SessionsController` (senha, contas antigas) |
| Entrar com o Google | `POST /auth/google_oauth2` → `/auth/google_oauth2/callback` | OmniAuth + `GoogleSessionsController` |
| Nickname#0000 | `/apelido` | `NicknamesController` |
| Esqueci minha senha | `/recuperar-senha` | `PasswordResetsController` (só contas com senha) |
| Minha conta / sair | `/conta`, `DELETE /sair`, `DELETE /sair-de-todos` | `AccountsController#show/destroy/destroy_all` |
| Gravar vídeo | `/gravar` | `RecordingsController` + `recorder_controller.js` |
| Zine | `/zine` | `ZinesController` + `ZinesHelper` |

Migração nova: `db/migrate/20260927200000_add_password_digest_to_users.rb` (rode `bin/rails db:migrate`).

---

## 1. Autenticação

### Regra

Só a landing (`/`) e as telas de acesso (cadastro, login, recuperação de senha) são públicas. Qualquer outra rota redireciona para `/entrar`; depois do login, a pessoa volta para a página que tentou abrir.

O antigo **perfil anônimo** (usuário criado automaticamente por cookie) foi removido.

### Como funciona

- **Entrar com o Google:** cadastro e login são o mesmo botão, "Continuar com o Google" (`shared/_google_button`, sempre por POST com token CSRF). O app pede só `openid email` e aceita apenas e-mail **confirmado** no Google. A conta é achada pelo `google_uid`; se não houver, pelo e-mail (uma conta antiga com o mesmo e-mail vira conta Google, mantendo trilha, vídeos e XP, e a senha antiga deixa de valer); se não houver nenhuma, é criada como aprendiz. Não existe cadastro como mentor: quem quer ser mentor pede pelo Perfil, e um administrador aprova.
- **Nickname#0000:** logo depois do primeiro login pelo Google, a pessoa escolhe o nickname (3 a 20 letras, números, `_`, `.` ou `-`, sem parecer telefone). O número de 4 dígitos (0001 a 9999) pode ser escolhido ou sorteado; nicknames iguais são permitidos, o par nickname#número não (sem diferenciar maiúsculas). Enquanto não escolher, o app manda para `/apelido`. É o nickname#0000 que mentores e outros skatistas veem.
- **Login com senha (contas antigas):** fica dentro de "Conta antiga" em `/entrar`. Contato inexistente e senha errada mostram a mesma mensagem, para não revelar quem tem conta. No Perfil, essas contas têm o botão para ligar ao Google.
- **Telefone:** aceito em qualquer formato — `(61) 99999-0000` e `61999990000` são o mesmo número (o modelo guarda só os dígitos).
- **Esqueci minha senha:** reaproveita o `AccessCode` (código de 6 dígitos com bcrypt, validade de 10 min e limite de tentativas). A resposta é a mesma com ou sem conta. Ao criar a senha nova, a sessão é encerrada em todos os aparelhos. Conta ligada ao Google não recebe código (entra só pelo Google).
- **Sessão:** cookie assinado e permanente com o `token` do usuário (`Authentication` concern). A sessão é reiniciada ao entrar e ao sair (proteção contra fixação de sessão). "Sair de todos os aparelhos" regenera o token.
- **Rate limit:** 10 tentativas a cada 3 minutos em cadastro, login e recuperação.

### Para desenvolvedores

- Rotas públicas são liberadas no controller com `allow_unauthenticated_access` (ex.: `PagesController` libera só `:landing`).
- `require_no_authentication` redireciona quem já está logado para fora das telas de cadastro/login.
- `current_user` pode ser `nil` apenas em telas públicas; nas demais, é garantido.
- As mensagens de validação do `User` estão em português no próprio modelo (o locale padrão do app é `en` e não há `rails-i18n`).

### Atenção

- **Contas antigas** criadas pelo fluxo de "salvar progresso" (só com código, sem senha) não conseguem entrar até usar **Esqueci minha senha** uma vez.
- **O código de recuperação ainda não é enviado** por e-mail/WhatsApp: ele aparece no log do servidor (`[Stance] código 123456 para ...`). A integração real entra em `app/services/access_code_delivery.rb`.

---

## 2. Página Gravar (`/gravar`)

Abre pelo botão amarelo **Gravar** do menu inferior.

### Fluxo

1. A pessoa escolhe a manobra (só aparecem as já liberadas na trilha) e escolhe **Gravar com a câmera** ou **Fazer upload de vídeo**.
2. **Câmera:** usa a API `MediaRecorder` com a câmera traseira. O contador para a gravação sozinho em 15 s. Grava em MP4 (Safari/iOS e Edge) ou WebM (Chrome/Android). Sem suporte à API (ex.: acesso por `http` fora de `localhost`), abre a câmera nativa do celular.
3. **Upload:** aceita MP4, MOV e WebM; o navegador lê a duração antes de enviar.
4. **Pré-visualização** com duração e tamanho, e botão **Descartar e escolher outro**.
5. O envio só é liberado com vídeo escolhido **e** checklist de segurança marcado.
6. O arquivo é enviado via `FormData` (multipart) com **barra de progresso**.
7. O servidor cria um `TrainingSession` (`status: in_progress`), anexa o vídeo pelo Active Storage e redireciona para a tela de resultado. Ao registrar o resultado, a análise da IA é disparada (fluxo já existente).

### Validações

Feitas no navegador (para feedback imediato) **e** no servidor (fonte da verdade):

| Regra | Limite | Onde está configurado |
| --- | --- | --- |
| Formato | MP4, MOV, WebM | `TrainingSession::CLIP_CONTENT_TYPES` |
| Tamanho | 40 MB | `config/initializers/stance.rb` (`max_clip_bytes`) |
| Duração | 15 s (+1 s de tolerância) | `config/initializers/stance.rb` (`max_clip_seconds`) |
| Checklist de segurança | 3 itens marcados | `TrainingSession#validate_recording` |

O formato é identificado pelo **conteúdo** do arquivo (Marcel), não pela extensão — um PNG renomeado para `.mp4` é recusado.

### Metadados salvos

- No `TrainingSession`: usuário, manobra, data, status e checklist.
- No blob do Active Storage (`custom_metadata`): `duration_seconds` e `source` (`camera` ou `upload`).
- A URL do vídeo não é gravada no banco: é gerada pelo Active Storage (`url_for(training_session.clip)`).

### Armazenamento na nuvem

Por padrão, os arquivos ficam em `storage/` (disco). Para usar AWS S3, Supabase Storage, Cloudflare R2 ou MinIO:

1. Adicione ao `Gemfile` e rode `bundle install`:
   ```ruby
   gem "aws-sdk-s3", require: false
   ```
2. Configure as variáveis de ambiente em produção:
   ```
   ACTIVE_STORAGE_SERVICE=amazon
   S3_BUCKET=...
   S3_ACCESS_KEY_ID=...
   S3_SECRET_ACCESS_KEY=...
   S3_REGION=...
   S3_ENDPOINT=...   # só para Supabase/R2/MinIO
   ```
   No Supabase, o endpoint é `https://<projeto>.supabase.co/storage/v1/s3`.

Nenhuma mudança de código é necessária (ver `config/storage.yml`).

### Limitações conhecidas

- A **duração** é validada com o valor medido pelo navegador. Validá-la no servidor exigiria `ffmpeg`/`ffprobe` instalado. O limite de tamanho vale sempre.
- O upload passa pelo servidor Rails, o que funciona bem até os 40 MB atuais. Para vídeos bem maiores, vale migrar para *direct upload* do navegador para a nuvem.
- Gravar direto pela câmera no celular exige `https` (ou `localhost`).

---

## 3. Aba Zine (`/zine`)

Abre pelo item **Zine** do menu inferior.

Todo vídeo gravado ou enviado aparece automaticamente, do mais recente para o mais antigo. Não há cópia: a lista vem direto dos treinos com vídeo (`TrainingSession.with_clip`). Cada pessoa vê só os próprios vídeos.

### Cada card mostra

- player do vídeo, nome e código da manobra;
- data e hora (no fuso do usuário, `users.time_zone`), duração e origem;
- linha de andamento: **Gravado → Resultado → Mentor → Devolutiva**;
- status atual e botão para o próximo passo.

| Etapa (`TrainingSession#analysis_stage`) | Status exibido | Botão |
| --- | --- | --- |
| `awaiting_result` | Registre o resultado para enviar ao mentor | Registrar resultado |
| `queued_offline` | Aguardando conexão para enviar | Registrar resultado |
| `pending` | Na fila do mentor · resposta em até 48h | Acompanhar devolutiva |
| `processing` | O mentor está vendo seu vídeo | Acompanhar devolutiva |
| `completed` | Devolutiva pronta (+ frase de destaque) | Ver devolutiva |
| `failed` | Não foi possível analisar | Ver detalhes |

Enquanto houver vídeo na fila ou sendo visto, a página se atualiza sozinha a cada 1 minuto (`poll_controller.js`), pausando se algum vídeo estiver tocando. A prévia de cache do Turbo foi desligada nessa página para o status nunca aparecer desatualizado.

### Atenção

- O vídeo só vai para a fila **depois que a pessoa registra o resultado** do treino.
- **Não há análise automática.** O vídeo fica `pending` ("na fila do mentor") até alguém preencher a devolutiva (`AiReview`): o que fez bem, onde foi o erro e o foco da próxima sessão. Ainda não existe tela para o mentor responder.
- A equipe vai decidir entre IA e reconhecimento corporal. Para ligar a análise automática: implemente `Ai::FallAnalyzer#call` e ative `config.x.stance.automatic_review` em `config/initializers/stance.rb`. Até lá, o `FallAnalyzer` recusa rodar (`NotConfigured`) em vez de inventar uma análise.

---

## Testes

```bash
bin/rails test
```

28 testes, incluindo:

- `test/integration/authentication_flow_test.rb` — cadastro só pelo Google, login com senha das contas antigas, logout, rotas protegidas, recuperação de senha;
- `test/integration/google_login_test.rb` — conta nova pelo Google, volta, e-mail não confirmado, ligação de conta antiga, regras do nickname#0000;
- `test/integration/recording_flow_test.rb` — envio válido, metadados, arquivo no storage, formato/tamanho/duração inválidos, checklist, manobra bloqueada;
- `test/integration/zine_test.rb` — acesso, lista vazia, cada etapa da análise, isolamento entre usuários.

Além dos testes, os fluxos foram verificados em navegador real (Edge com câmera simulada).

> No Windows, `fixture_file_upload` precisa do terceiro argumento `true` (modo binário). Em modo texto, o Windows interrompe a leitura no byte `0x1A` e corrompe o arquivo de teste.

## Pendências sugeridas

1. Integrar o envio real do código de recuperação (e-mail/WhatsApp) em `AccessCodeDelivery`.
2. Definir como o mentor responde (tela própria ou WhatsApp) e, se a equipe escolher análise automática (IA ou reconhecimento corporal), implementá-la em `Ai::FallAnalyzer`.
3. Configurar o storage em nuvem em produção (seção acima).
4. Corrigir o espaçamento das telas antigas que usam margens do Tailwind (ex.: `/comecar/idade`): o reset `* { margin: 0 }` do `custom_styles.css` anula essas classes.
