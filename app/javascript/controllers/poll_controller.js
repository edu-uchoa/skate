import { Controller } from "@hotwired/stimulus"

// Recarrega a página de espera até a devolutiva da IA ficar pronta.
export default class extends Controller {
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.timer = setInterval(() => {
      if (document.visibilityState === "visible") {
        window.Turbo ? Turbo.visit(window.location.href, { action: "replace" }) : window.location.reload()
      }
    }, this.intervalValue)
  }

  disconnect() { clearInterval(this.timer) }
}
