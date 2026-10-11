---
name: stance-visual
description: Identidade visual do app Stance (skate) e como montar telas bonitas e consistentes com ela. Use sempre que for criar ou alterar uma tela, view ERB, partial, CSS, cor, fonte, ícone, botão, card, formulário ou texto visível no app — inclusive quando o usuário disser "deixa com a minha estética", "fica bonito", "arruma o layout", "está quebrado/espremido" ou mandar um print de uma tela. Evita o erro clássico do projeto: margens do Tailwind que não funcionam.
---

# Visual Stance

O app imita um celular (moldura de até 414px no computador, tela cheia no celular),
fundo quase preto, amarelo como cor de ação e laranja como destaque, títulos em
caixa-alta com fonte Outfit e textos em Inter. Tom de conversa de skatista brasileiro,
direto e animado.

## A regra que mais quebra telas

`app/assets/stylesheets/custom_styles.css` começa com `* { margin: 0; padding: 0; }`.
Esse reset **anula as classes de espaçamento do Tailwind** (`mt-md`, `mb-lg`,
`space-y-xs`, `p-sm`...). As telas antigas (Idade, Plano, Ajuda, Retorno) ficaram
espremidas por isso. Portanto:

- Espaçamento com `display: flex/grid` + `gap`, nunca com margens utilitárias.
- Prefira as classes prontas do `custom_styles.css` (catálogo em
  `references/componentes.md`) a inventar estilos novos.
- Código novo: estilos em classes no `custom_styles.css`, não em `style="..."` gigante.
  O inline existente nas telas antigas pode ficar; não reescreva o que não foi pedido.

## Tokens (definidos em `:root` no custom_styles.css)

| Uso | Variável | Valor |
| --- | --- | --- |
| Fundo da tela | `--bg-color` | #121316 |
| Cartões | `--surface-color` | #1f1f23 |
| Fundo mais escuro / sombra | `--surface-low` | #0d0e11 |
| Bordas | `--surface-high` / `--surface-highest` | #292a2d / #343538 |
| Ação principal (botões, destaques) | `--primary-color` | #ffb800 |
| Sombra do amarelo | `--primary-shadow` | #6b4c00 |
| Destaque secundário (selos) | `--secondary-color` | #fd591e |
| Sucesso / concluído | `--tertiary-color` | #30D158 |
| Erro / perigo | `--error-color` | #ff5a5f |
| Texto principal / secundário | `--text-on-surface` / `--text-variant` | #e3e2e6 / #d5c4ab |
| Fontes | `--font-display` / `--font-body` | Outfit / Inter |

Ícones: Material Symbols Outlined (`<span class="material-symbols-outlined">nome</span>`),
já carregados no layout. Escolha ícones em fonts.google.com/icons.

## Esqueleto de uma tela

Toda view é renderizada dentro de `.screen` (flex em coluna, com rolagem) no layout
`app/views/layouts/application.html.erb`. Comece com `content_for :section`.

- **Tela de formulário ou mensagem** (login, idade, ajuda, retorno): `section.auth-screen`
  → `header.auth-head` (ícone `auth-icon`, `step-indicator` opcional, `h2.screen-title`,
  `p.screen-desc`) → `render "shared/errors", record: ...` → `form.auth-form` com
  `auth-field`/`auth-label`/`auth-input` → botão `tactile-btn-primary` com
  `<span>Texto</span><span class="material-symbols-outlined btn-arrow">arrow_forward</span>`.
- **Escolha entre opções** (radio): `fieldset.choice-list` + `label.choice-card` com o
  input dentro, `choice-icon`, `choice-text` (`strong` + `small`) e `choice-mark`. O
  destaque do marcado é feito por CSS (`:has`), sem JavaScript.
- **Passo da trilha** (drill): `step-indicator` "PASSO X • DRILL" + `screen-title` +
  vídeo (`video-container`) + guia (`maneuvers/guides/`) + botão "Praticar este passo".
- **Telas com dados fixos de exemplo** (Loja, Avatar, Deck, Picos) são só visuais; não
  invente números novos sem combinar.

## Texto

- Português do Brasil, frases curtas, vocabulário de skate (rolê, pico, shape, lixa,
  bowl, mandar a manobra). O nome do app é **Stance** — nunca "Skate" nem "Sakte".
- Títulos em caixa-alta vêm do CSS (`text-transform`): escreva o texto normal no ERB.
- Mensagens de erro em português e sem nome de campo em inglês: prefira
  `errors.add(:base, "...")` a `errors.add(:birth_year, ...)` (o locale padrão é `en`).

## Voz e conteúdo (dos documentos de estratégia da equipe)

O público trava por **medo de se machucar** e **vergonha de ser visto**. Por isso:
- A voz é a do **amigo mais velho que já caiu** e já ficou parado, não a do instrutor
  que avalia. Nada de cobrança ("você precisa", "não desista!"); prefira acolher
  ("tudo bem parar", "se cair, você sabe rolar").
- **Sem número inventado.** Estatística só com fonte (ex.: "reduz 90% dos
  machucados" não tem fonte e não deve aparecer).
- **Privado por padrão:** nada na tela expõe a pessoa a estranhos (feed, ranking
  público, clipe visível para outros) sem ela escolher.
- **Sem cobrança diária:** metas diárias punem quem parou por lesão. A ofensiva existe
  (pedido do dono), mas é **por sessão de skate**, não diária (`Streak`): rolê marcado no
  mapa + vídeo de uma tarefa no horário + resultado enviado; só zera depois de 7 dias
  sem sessão, e uma parada pode ser justificada (um mentor avalia). Diga "Tudo bem
  parar". Não crie avisos de "você vai perder a ofensiva" nem metas diárias.
- Imagens e exemplos com representação feminina, e português de rua.

## Antes de dar como pronto

Confira no navegador com a skill **stance-responsivo**. Compare o print com uma tela
vizinha já aprovada (ex.: `/entrar` para formulários, `/manobras/escolher-setup` para
drills): espaçamentos, botão amarelo com sombra, títulos em caixa-alta, nada encostado
na borda nem escondido atrás do menu inferior.
