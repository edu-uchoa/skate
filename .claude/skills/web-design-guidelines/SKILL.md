---
name: web-design-guidelines
description: Revisão de interface do FlipaAi contra as Web Interface Guidelines (acessibilidade, foco, formulários, toque no celular, áreas seguras, animação e textos). Use quando pedirem "revisa a tela", "confere a acessibilidade", "audita o design", "revisa a UX", "está tudo certo nesta tela?", ou antes de lançar uma tela nova ou mudança grande de layout.
metadata:
  author: vercel (adaptado para o FlipaAi)
  version: "1.0.0-flipaai"
  argument-hint: <arquivo-ou-padrão>
---

# Web Interface Guidelines (no FlipaAi)

Adaptado de `vercel-labs/agent-skills` (skill `web-design-guidelines`, licença MIT; veja
`LICENSE`). Diferenças do original:
- As regras ficam guardadas aqui (`guidelines.md`), em vez de serem buscadas na internet a cada
  revisão. Assim ninguém de fora muda o que o Claude segue no projeto.
- Há notas de como aplicar as regras num app Rails, com textos em português.

## Como revisar

1. Leia `guidelines.md` (ao lado deste arquivo) inteiro.
2. Leia os arquivos pedidos: views ERB, partials, `custom_styles.css` e controllers Stimulus.
   Se não disserem quais, pergunte.
3. Confira cada regra e liste os achados no formato `arquivo:linha` do fim de `guidelines.md`.

## Como as regras valem no FlipaAi

- **Rails e ERB, não React:**
  - `link_to` gera `<a>` (navegação) e `button_to` ou `f.button` gera `<button>` (ação);
  - onde a regra fala de `onClick` ou `useState`, veja o equivalente em Stimulus
    (`data-action`) e na URL (`?aba=...`);
  - as regras de "Hydration Safety" não se aplicam: o HTML vem pronto do servidor.
- **Tailwind:** os exemplos com classes (`focus-visible:ring-*`, `truncate`) valem também para
  as classes próprias de `custom_styles.css`.
- **Textos em português:**
  - não use Title Case: o FlipaAi escreve em frase normal, e os títulos em caixa-alta vêm
    do CSS;
  - a voz é a da **flipaai-visual** (amigo mais velho que já caiu). Em conflito de estilo,
    vale a flipaai-visual.
- **Datas e números:** o app formata no servidor (`strftime`, no fuso do usuário). Só aponte
  quando houver formato montado no navegador.
- **Celular é o principal.** Dê atenção extra a toque, `env(safe-area-inset-*)`, zoom e
  tamanho dos alvos (veja também a **flipaai-responsivo**).

## Já conhecido

`layouts/application.html.erb` usa `maximum-scale=1.0, user-scalable=no`, o que a regra
aponta como antipadrão porque impede o zoom de quem enxerga mal. Foi colocado para o iPhone
não dar zoom ao tocar nos campos. A troca correta é deixar os campos com 16px e liberar o
zoom. Está anotado como pendência, não como decisão final.
