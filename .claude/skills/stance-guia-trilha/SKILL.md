---
name: stance-guia-trilha
description: 'Modelo para criar ou editar o conteúdo dos passos da trilha do Stance (drills e manobras, ex.: 0.1 Setup, 0.2 Equipamento, 0.3 Queda controlada) — pesquisa em fontes de profissionais, texto resumido em português sem citar marcas e a estrutura visual do guia. Use sempre que o usuário pedir para "criar a tela do passo", "colocar explicação/orientações" num passo ou manobra, "seguir o modelo da trilha", ou falar de conteúdo educativo de skate (setup, equipamento, queda, postura, manobras).'
---

# Guias dos passos da trilha

Cada passo da trilha mostra o vídeo no topo e, logo abaixo, um **guia rápido** que
ensina o essencial para quem está começando. Os guias de 0.1 e 0.2 são a referência:
`app/views/maneuvers/guides/_escolher_setup.html.erb` e `_equipamento.html.erb`.

## Onde fica

- Arquivo: `app/views/maneuvers/guides/_<slug com _>.html.erb` (o slug está em
  `db/seeds.rb`; `escolher-setup` → `_escolher_setup`). Esqueleto pronto em
  `.claude/skills/stance-guia-trilha/assets/guia-modelo.html.erb`.
- Drills (`kind: :drill`) já mostram o guia automaticamente: `maneuvers/_drill.html.erb`
  renderiza o arquivo se ele existir. Manobras comuns usam `_maneuver.html.erb`, que
  **ainda não tem esse gancho**. Se precisar, copie as 3 linhas do `_drill` para lá
  logo depois do `video-container`.
- O vídeo indicativo do topo fica como está: o usuário vai gravar os vídeos depois.
- Estilos: só classes `guide-*` já existentes (catálogo na skill **stance-visual**).
  Crie classe nova só se nenhuma servir, e no fim do `custom_styles.css`.

## Pesquisa

1. Busque em fontes que o usuário confia, nesta ordem: fabricantes de peças e marcas de
   skate (os guias deles, não a propaganda), skatistas profissionais (entrevistas,
   aulas), revistas de skate, entidades médicas (para segurança e lesões). Lojas
   especializadas servem de complemento.
2. Só use números (medidas, durezas, tamanhos) que aparecem em pelo menos duas fontes.
3. Guarde a lista de links: ela vai na resposta ao usuário, **não na página**.

## Texto da página

- **Nenhuma marca** e nenhum nome de skatista (muitos nomes de profissionais também são
  marcas). Para atribuir um conselho: "quem é profissional...", "os profissionais de bowl...".
- Resumido: quem lê está no celular, de pé, com o skate do lado. Frases curtas, uma
  ideia por item. Detalhe longo vai no bloco recolhível (`guide-details`).
- Vocabulário do skate brasileiro: shape, lixa, truck, rodas, rolamentos, parafusos de
  base, calço, kingpin, rolê, pico, bowl, transição. Shape em polegadas (8.0"), rodas em
  mm e dureza "A", tênis em numeração brasileira.
- Segurança acima de tudo: nada que incentive andar sem proteção ou arriscar além do
  passo atual. Se o assunto é lesão, siga as entidades médicas.
- Títulos com energia (o usuário gosta de "Proteção para ter um rolê mais leve e
  seguro!"); escreva normal, o CSS deixa em caixa-alta.

## Estrutura (adapte ao assunto)

1. `guide-head`: "Guia rápido" + título + 2–3 frases de por que importa.
2. Card 1 com abas **Rua / Bowl** quando a resposta muda com o estilo (setup,
   equipamento). Se não muda (ex.: postura), troque por uma lista ou passo a passo.
3. `guide-tip`: a recomendação coringa ("na dúvida...", "pouca grana?").
4. Cards numerados com o restante (tamanho, onde comprar, erros comuns...).
5. `guide-details`: passo a passo ou detalhes técnicos, recolhido.

## Teste

Adicione um teste em `test/integration/maneuver_guide_test.rb` no padrão dos
existentes: cria a manobra com o slug, abre `maneuver_path` e confere que o guia vem
logo depois do vídeo (`.video-container + .guide`) e que as partes principais existem.
Depois confira no navegador com **stance-responsivo** (abas trocando, bloco abrindo,
botão "Praticar este passo" funcionando) e entregue com **stance-entrega**.
