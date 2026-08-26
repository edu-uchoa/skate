import { Controller } from "@hotwired/stimulus"

// Indicador de "Modo Offline" no topo das telas de execução.
export default class extends Controller {
  static targets = ["icon", "label"]

  connect() {
    this.update()
    this.boundUpdate = this.update.bind(this)
    window.addEventListener("online", this.boundUpdate)
    window.addEventListener("offline", this.boundUpdate)
  }

  disconnect() {
    window.removeEventListener("online", this.boundUpdate)
    window.removeEventListener("offline", this.boundUpdate)
  }

  update() {
    const online = navigator.onLine
    if (this.hasIconTarget) this.iconTarget.textContent = online ? "wifi" : "cloud_off"
    if (this.hasLabelTarget) this.labelTarget.textContent = online ? "Online" : "Modo offline"
  }
}
