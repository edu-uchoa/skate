import { Controller } from "@hotwired/stimulus"

// Mapa da Trilha: o mapa é mais alto que a tela e rola na vertical (barra à direita).
// Ao abrir, centraliza o nó atual (a seta laranja) para a pessoa ver onde parou.
export default class extends Controller {
  static targets = ["current"]

  connect() {
    if (!this.hasCurrentTarget) return
    this.element.scrollTop = this.currentTarget.offsetTop - this.element.clientHeight / 2
  }
}
