# Catálogo de peças do custom_styles.css

Leia quando for montar uma tela e precisar saber qual classe usar. Todas ficam em
`app/assets/stylesheets/custom_styles.css`. Procure pelo nome da classe para ver o CSS.

## Títulos e textos
| Classe | Para quê |
| --- | --- |
| `step-indicator` | Linha pequena amarela em caixa-alta acima do título ("PASSO 1 DE 3 • 33%") |
| `screen-title` | Título da tela (Outfit 900, caixa-alta) |
| `screen-desc` | Subtítulo/explicação curta (cor `--text-variant`) |
| `main-headline` | Título grande da landing |
| `sub-headline-card` + `sub-headline-title` + `sub-headline-body` | Cartão com leve rotação, para destaque de texto |
| `tape-badge` / `version-badge` | Selos laranja tipo fita adesiva. `version-badge` é `position: absolute`: o pai precisa de `position: relative`, senão o selo vai parar no canto da tela |

## Botões e links
| Classe | Para quê |
| --- | --- |
| `tactile-btn-primary` | Botão amarelo principal com sombra "3D" (texto à esquerda, ícone `btn-arrow` à direita) |
| `auth-secondary-btn` (+ `.danger`) | Botão secundário com borda |
| `secondary-link-btn` | Link discreto abaixo do botão ("Voltar ao Mapa") |
| `auth-link` / `auth-muted-link` | Links sublinhados (amarelo / discreto) |
| `auth-back` | "← Voltar" no topo |

## Formulários e mensagens
| Classe | Para quê |
| --- | --- |
| `auth-screen` | Coluna centralizada com `gap: 20px` (serve para qualquer formulário, não só login) |
| `auth-head` | Cabeçalho da tela (ícone + títulos) |
| `auth-icon` | Ícone grande amarelo |
| `auth-form` / `auth-field` / `auth-label` / `auth-input` | Formulário em coluna, rótulo e campo |
| `auth-input-code` | Campo de número grande e espaçado (código, ano) |
| `auth-hint` / `auth-note` | Dica abaixo do campo / nota com ícone no rodapé |
| `auth-errors` | Lista de erros em vermelho (é o que `shared/_errors` usa) |
| `auth-card` + `auth-card-label` + `auth-card-value` | Cartão informativo (ex.: "Seu ponto de partida") |
| `card-list` + `card-list-label` | Lista dentro de um `auth-card` (drills recomendados, aquecimento) |
| `choice-list` / `choice-card` (+ `.danger`) / `choice-icon` / `choice-text` / `choice-mark` | Cartões de escolha com radio escondido |
| `options-list` / `option-card` | Opções do diagnóstico (versão antiga, com JS inline) |
| `check-item` / `check-box-square` | Itens do checklist de segurança do treino |
| `flash-message` (+ `.alert`) | Aviso após redirecionamento (renderizado pelo layout) |

## Trilha e guias
| Classe | Para quê |
| --- | --- |
| `track-map-frame` / `track-map` / `track-map-canvas` | Mapa da trilha, desenhado no app (sem imagem), visto de cima como mapa de mundo de videogame: uma ilha da cidade por módulo, de cima para baixo, rolando na vertical com a barra à direita. Layout em `TracksHelper#track_map_layout` (sem nome no topo) |
| `map-scene` (partial `tracks/_map_scene`) | Fundo em SVG: água, ilhas com cais, rua da trilha com faixa tracejada, rua de cada módulo com faixa de pedestre e ponte de tábuas nos canais |
| Peças do cenário (`tracks/_map_symbols`, um `<symbol>` por peça) | Prédios e galpão grafitados, loja de skate, pista com bowl, mini rampa, funbox, kicker, ledge, corrimão, escada, praça, gramado, quadra, estacionamento, carros, barcos e sujeira (manchas, rachaduras, buracos, lixo). Quem escolhe onde cada uma vai é `TracksHelper::Scenery`: semente fixa (sai sempre igual) e nada em cima da rua, das bolinhas, dos nomes ou das placas. Cores variáveis por `<use style="--roof/--wall/--tag-a/--tag-b/--paint">`. Para uma peça nova: desenhe o `<symbol id="map-nome">`, ponha o tamanho em `Scenery::SIZES` e use-a em `THEMES`/`FILL` |
| `map-node` (`.is-completed` check, `.is-current` seta, `.is-open` cadeado aberto; sem classe = bloqueado) + `map-node-label` | Bolinha de cada tarefa e o adesivo com o nome ao lado |
| `map-sign` / `map-flag` | Placa azul de cada módulo (na rua do módulo) e Largada/Chegada, em HTML por cima do cenário |
| `floating-lesson-card` | Cartão "Módulo atual" abaixo do mapa |

## Perfil, avatar e skate (/conta)
| Classe | Para quê |
| --- | --- |
| `profile-hero` / `profile-xp` / `profile-xp-label` | Topo do Perfil: avatar, nível e barra de XP |
| `profile-stats` + `profile-stat` (`.is-streak`, `.is-soon`) | Grade de números (ofensiva, estilo, tarefas, rank "Em breve") |
| `profile-tabs` / `profile-panel` (`.is-avatar`, `.is-skate`) | Abas só com CSS (radios `#profile-tab-avatar` / `#profile-tab-skate`) |
| `profile-editor` / `profile-preview` / `customizer-group` / `customizer-chip` / `customizer-swatch` | Editor com prévia grudada no topo e opções em "chips". A prévia troca na hora com `data-controller="customizer"` |
| `avatar` (SVG, `avatars/_avatar`) / `deck` (SVG, `decks/_deck`) | Desenhos em camadas: `customizer_layer` (data-part/data-option); cores por variáveis `--av-*` e `--deck-*`. Opções em `Avatar::OPTIONS` e `Deck::TYPES` |
| Estilo do avatar | Personagem de jogo de skate de hoje (referência: prints de Session do dono): proporção de gente, roupa larga e sem marca, luz da esquerda. O volume vem de degradês por cima da cor (`url(#cyl-uid)` nas laterais, `#fall-uid` de cima para baixo, `#ao-uid` onde uma parte encosta na outra). Desenhe só o lado esquerdo e espelhe com `avatar_mirror`/`avatar_both` (AvatarsHelper). A cabeça é encolhida em volta do queixo (`head`). Segura o skate do Perfil (`deck:`), e `crop: true` mostra só do peito para cima (topo do Perfil). Roupa nova: uma camada `layer.(:top, "chave")` + a opção em `Avatar::OPTIONS` |
| `video-container` / `play-circle` / `video-badge` | Vídeo (ou placeholder) no topo do passo |
| `guide`, `guide-head`, `guide-title`, `guide-lead` | Estrutura do guia de um passo |
| `guide-card` + `guide-card-label` | Cartão numerado ("1. Escolha o seu estilo") |
| `guide-tabs` / `guide-tab` / `guide-panel-rua` / `guide-panel-bowl` | Abas Rua/Bowl só com CSS (radios `name="guide-style"` com `value="rua"`/`"bowl"`). Ícones: `location_city` (Rua) e `render "shared/icon_bowl"` (Bowl, SVG próprio; o Material Symbols não tem bowl de skate) |
| `guide-specs` (+ `.is-wide`) | Lista rótulo → explicação (Shape, Truck...). `.is-wide` para rótulos longos |
| `guide-gear`, `guide-gear-name`, `guide-tag` (`.is-must`, `.is-start`) | Lista de itens com etiqueta (Obrigatório, Começando, Opcional) |
| `guide-table`, `guide-tip`, `guide-list`, `guide-hint` | Tabela, dica com barra amarela, lista com marcador amarelo, nota pequena |
| `guide-details` + `summary` + `guide-steps` | Bloco recolhível (passo a passo) |

## Zine, gravação e IA
`zine-*` (cards de vídeo e etapas da análise), `rec-*` (tela Gravar: câmera, upload,
checklist e progresso), `feedback-block` / `ia-loader-card` (devolutiva da IA).
