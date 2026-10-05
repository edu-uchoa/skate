---
name: stance-entrega
description: Fluxo de trabalho para qualquer mudança no app Stance (Rails, skate) — da leitura do código ao commit. Use sempre que for alterar código, telas, textos, CSS, testes ou configuração deste repositório, mesmo em mudanças pequenas como trocar um título, e também quando o usuário pedir "faça o commit", "continue adicionando aos commits", "pode subir", "abre o PR" ou perguntar se algo está pronto. Garante branch certa, testes, conferência no navegador, um commit por mudança e nada enviado ao GitHub sem autorização.
---

# Entrega de mudanças no Stance

O dono do produto está aprendendo a desenvolver e um parceiro revisa tudo antes de ir
para o GitHub. Por isso cada mudança precisa chegar **testada, isolada num commit próprio
e explicada em linguagem simples**. O objetivo é que o parceiro consiga revisar commit a
commit e que qualquer mudança possa ser desfeita sozinha.

## 1. Antes de mexer

1. `git branch --show-current` e `git status --short`.
   - Nunca trabalhe na `main`: ela espelha o que o parceiro conhece. Se estiver nela,
     crie uma branch (`git checkout -b melhorias-<tema>`) e avise.
   - Se houver alterações soltas de outra tarefa, não as misture: pergunte se pode
     commitá-las antes (cada mudança no seu commit).
2. Leia o código envolvido antes de propor. Reproduza o problema (print, teste ou
   `bin/rails runner`) para ter certeza da causa — várias vezes a causa real era outra
   (ex.: o mapa desalinhado vinha do `object-fit: cover`, não das coordenadas).
3. Se a mudança envolve uma decisão de produto (texto, regra da trilha, o que aparece
   para o usuário), siga o pedido e diga claramente qual decisão você tomou no lugar dele.

## 2. Fazendo a mudança

- Siga o jeito do código ao redor (nomes, comentários em português, estrutura).
- Tela ou CSS → siga a skill **stance-visual**.
- Conteúdo de passo da trilha → siga a skill **stance-guia-trilha**.
- Login, dados do usuário, upload, formulário, segredo ou gem → siga **stance-seguranca**.
- Não amplie o escopo por conta própria. Achou outro problema no caminho? Anote e
  conte ao usuário no final, com a sugestão de correção como mudança separada.

## 3. Conferindo

1. Regra nova ou bug corrigido → escreva um teste que falharia sem a correção
   (`test/models/` para regras, `test/integration/` para telas e fluxos).
2. `bin/rails test` — a suíte inteira tem que passar. Para rodar só alguns testes no
   Git Bash, use `MSYS_NO_PATHCONV=1 bin/rails test arquivo_test.rb -n "/trecho/"`:
   sem isso, o `/trecho/` vira um caminho do Windows e nenhum teste roda ("0 runs").
   Para provar que um teste novo pega o bug, rode-o uma vez sem a correção (deve falhar).
3. `bin/rubocop <arquivos .rb alterados>` — o CI do GitHub roda o RuboCop.
4. Mudou tela, CSS ou formulário → confira no navegador com a skill **stance-responsivo**
   (prints em celular e computador e, para formulários, o envio de verdade). Testes de
   integração não pegam problemas de Turbo/JS: os botões de Ajuda e Retorno passavam nos
   testes e não funcionavam no navegador.
5. Limpe o que criou para testar: usuários de teste no banco de desenvolvimento e o
   servidor da porta 3001. O servidor do usuário (porta 3000) não é tocado, com uma
   exceção: depois de uma **migração** ele precisa ser reiniciado, senão quebra em toda
   página (ex.: "Undeclared attribute type for enum"), porque guarda as colunas de
   quando ligou. Rode `bin/rails db:migrate` e `bin/rails db:test:prepare` e reinicie
   o servidor avisando o usuário. No Windows, `bin/rails restart` **derruba** o Puma
   em vez de reiniciar, e `bin/dev` não funciona (o foreman não inicia os processos):
   pare pelo PID de `tmp/pids/server.pid` e suba de novo com `bin/rails server`.

## 4. Commit (um por mudança)

Faça o commit quando o usuário pedir ou quando ele já tiver dito para ir commitando cada
mudança pronta ("continue adicionando aos commits"). Na dúvida, pergunte.

- Adicione só os arquivos desta mudança (`git add <arquivos>`), nunca `git add -A` às cegas.
- Mensagem em português, **sem acentos** (padrão do histórico do projeto), no formato
  `tipo: descricao curta` + corpo explicando o problema e o que mudou em tópicos.
  Tipos: `feat` (novo), `fix` (correção), `style` (visual), `copy` (texto),
  `refactor`, `test`, `docs`, `chore`.
- Termine com a linha de coautoria indicada pelo sistema, quando houver.
- Os avisos `LF will be replaced by CRLF` são normais no Windows; não afetam o código.

Exemplo:

```
fix: aceita o nivel avancado no diagnostico

A opcao "Ja mando Ollie com firmeza" enviava level=advanced, que nao
existia no enum: quem a escolhia via uma pagina de erro.

- Diagnosis: novo nivel advanced (3)
- DiagnosisPlanner: entrada na trilha em 3.0 (Shove-it)
- Teste do ponto de entrada para o nivel avancado
```

## 5. Nada vai para o GitHub sem autorização

`git push`, abrir Pull Request ou mexer na `main` só com pedido explícito do usuário
naquela conversa. Commit é local e privado; push publica. O parceiro revisa antes.

## 6. Resposta final ao usuário

Em português simples (ele está aprendendo), curta e nesta ordem:
1. O que mudou, do ponto de vista de quem usa o app.
2. Como foi testado (testes, prints, envio real) — com números ("31 testes passam").
3. Decisões que você tomou no lugar dele e problemas encontrados fora do escopo.
4. Commit feito (hash + título) e se ainda falta algo, ou a pergunta "posso commitar?".

Use links clicáveis para arquivos (`[arquivo.rb](caminho/arquivo.rb#L10)`).
