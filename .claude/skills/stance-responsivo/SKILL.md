---
name: stance-responsivo
description: Como garantir que as telas do app Stance funcionam e ficam bem no celular (Android e iPhone/Safari), em tela baixa e no computador — e como conferir isso de verdade com prints no navegador. Use sempre que uma tela, CSS, layout, vídeo, câmera, formulário ou JavaScript for criado ou alterado, antes de dizer que algo está pronto, e quando o usuário falar de celular, iPhone, Safari, "responsivo", "cortado", "desalinhado", "não aparece" ou mandar print de uma tela.
---

# Responsivo de verdade

O app é usado principalmente no celular. No computador ele aparece numa moldura de
414×896px (`.phone-container`, a partir de 641px de largura). Uma tela só está pronta
depois de vista em pelo menos **celular** e **computador**, e formulários depois de
**enviados** no navegador: o Turbo esconde problemas que os testes de integração não
pegam (já aconteceu com Ajuda e Retorno).

## Regras de layout

- Altura: use flex (`flex: 1` + `min-height`) em vez de `height: calc(100vh - ...)`.
  O `vh` muda com a barra do navegador do celular; o layout já usa `100dvh`.
- Imagem que precisa alinhar com elementos por cima (ex.: mapa da trilha): mantenha a
  proporção da imagem (`aspect-ratio`) e role no lado que sobrar. `object-fit: cover`
  corta diferente em cada tela e desalinha tudo.
- Nada importante atrás do menu inferior nem de cartões flutuantes: prefira o cartão
  no fluxo da página a `position: absolute` por cima do conteúdo.
- Toque: alvos de pelo menos ~40px; nada que dependa de `:hover`.
- Teste em tela baixa (390×600): é onde as coisas se sobrepõem.

## iPhone / Safari

- `<video>` sempre com `playsinline` (sem ele o iPhone abre em tela cheia). Faltam
  ainda em `maneuvers/_drill.html.erb` e `_maneuver.html.erb`.
- Câmera dentro da página (`getUserMedia`/`MediaRecorder`) só em **HTTPS** ou
  `localhost`. Por `http://IP` o app cai na câmera nativa (input `capture`).
- `:has()`, `aspect-ratio` e `100dvh` exigem iOS 15.4+. Isso é aceitável, mas não use
  recursos mais novos sem um plano B.
- `ApplicationController` tem `allow_browser versions: :modern`, que **bloqueia Safari
  abaixo de 17.2**. Há uma decisão pendente com o usuário para baixar para 15.4.
- Vídeos WebM (gravados no Android) podem não tocar em iOS antigo.
- Ícone de tela inicial (`apple-touch-icon`) e o manifesto (`pwa/manifest.json.erb`, ainda
  "Skate" e vermelho) estão pendentes.
- Para testar num iPhone real na mesma rede: `bin/rails server -b 0.0.0.0` e abrir
  `http://<IPv4 do PC>:3000` (liberar no firewall do Windows).

## Conferindo com prints (Windows, Edge sem janela)

Scripts em `.claude/skills/stance-responsivo/scripts/`. Salve os prints no diretório de
rascunho (scratchpad) da sessão, não no repositório.

1. **Servidor de teste na porta 3001** (o do usuário fica na 3000 e não é tocado), em
   segundo plano:
   `bin/rails server -p 3001 -P tmp/pids/server_3001.pid`
   Espere `curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/up` dar 200.
2. **Usuário de teste**:
   `bin/rails runner .claude/skills/stance-responsivo/scripts/usuario_teste.rb criar`
   (`novo` para telas de Idade/Diagnóstico).
3. **Prints**:
   `bundle exec ruby .claude/skills/stance-responsivo/scripts/prints.rb --email teste.prints@stance.dev --saida <scratchpad>/prints --tamanhos celular,baixo,desktop /trilha /manobras/escolher-setup`
   A saída mostra o status de cada página e avisa se a tela de erro do Rails apareceu.
4. **Olhe os prints** com a ferramenta de leitura de imagens. Para comparar muitas telas:
   `bundle exec ruby .claude/skills/stance-responsivo/scripts/folha.rb <saida.png> <prints...>`.
5. **Interação** (abas, botões, envio de formulário): escreva um roteiro Selenium curto
   no mesmo estilo de `prints.rb` (clicar no `label`, enviar, conferir `current_url` e o
   título da tela seguinte). Se um envio "não faz nada", leia o log do servidor de teste:
   se o POST chegou e respondeu, o problema é Turbo (redirect para outro site ou
   `render` com 200 depois de POST), não o formulário.
6. **Limpeza**: `usuario_teste.rb apagar` e pare o servidor:
   PowerShell `Stop-Process -Id (Get-Content tmp\pids\server_3001.pid) -Force`, depois
   apague o pid. Confirme que a porta 3001 ficou livre.

Avisos `VIPS-WARNING` no Windows são inofensivos; filtre com `grep -v VIPS`.
