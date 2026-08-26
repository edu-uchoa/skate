import { Controller } from "@hotwired/stimulus"

// Marca o envio como "offline" quando não há conexão, para o servidor colocar
// a sessão na fila em vez de tentar processar o vídeo.
export default class extends Controller {
  static targets = ["flag"]

  connect() {
    this.element.addEventListener("submit", () => {
      this.flagTarget.value = navigator.onLine ? "" : "1"
    })
  }
}
