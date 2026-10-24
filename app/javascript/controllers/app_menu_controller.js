import { Controller } from "@hotwired/stimulus"

// Menu do ☰ (topo): abre um painel com os atalhos que não cabem no menu de baixo.
// Fecha ao tocar fora (no fundo escuro: no iPhone, tocar num lugar sem botão não avisa a
// página), no Esc, ao escolher um item e antes de o Turbo guardar a tela (para o "voltar"
// não mostrar o menu aberto). Funciona com toque e com teclado.
export default class extends Controller {
  static targets = ["button", "panel", "backdrop"]

  connect() {
    this.closeOnEscape = (event) => { if (event.key === "Escape") this.close(true) }
    this.closeBeforeCache = () => this.close()
    document.addEventListener("keydown", this.closeOnEscape)
    document.addEventListener("turbo:before-cache", this.closeBeforeCache)
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.removeEventListener("turbo:before-cache", this.closeBeforeCache)
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close(true)
  }

  open() {
    this.panelTarget.hidden = false
    this.backdropTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.panelTarget.querySelector("a, button")?.focus()
  }

  // returnFocus: true quando fecha pelo teclado ou pelo próprio botão (o foco volta ao ☰).
  close(returnFocus = false) {
    if (!this.hasPanelTarget || this.panelTarget.hidden) return
    this.panelTarget.hidden = true
    this.backdropTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    if (returnFocus === true) this.buttonTarget.focus()
  }
}
