import { Controller } from "@hotwired/stimulus"

// Mapa da Trilha: o mapa é mais largo que a tela e rola na horizontal.
// Ao abrir, centraliza o nó atual para a pessoa ver onde parou.
export default class extends Controller {
  static targets = ["current"]

  connect() {
    if (!this.hasCurrentTarget) return
    this.element.scrollLeft = this.currentTarget.offsetLeft - this.element.clientWidth / 2
  }
}
