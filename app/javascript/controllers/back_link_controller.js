import { Controller } from "@hotwired/stimulus"

// "Voltar" que volta para a tela anterior do app, como o botão do navegador: a tela
// reaparece como estava, com o que já foi digitado (ex.: o ano na tela de idade). Sem
// tela anterior no app (link aberto direto, ou o app instalado acabou de abrir), segue
// o próprio link. Funciona igual no celular, no navegador e no app instalado.
export default class extends Controller {
  go(event) {
    // O Turbo numera as telas visitadas desde que o app abriu; 0 é a primeira.
    const index = window.history.state?.turbo?.restorationIndex
    if (!(index > 0)) return

    event.preventDefault()
    window.history.back()
  }
}
