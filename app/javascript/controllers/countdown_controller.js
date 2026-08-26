import { Controller } from "@hotwired/stimulus"

// Contagem regressiva para reenviar o código de acesso.
export default class extends Controller {
  static targets = ["label", "action"]
  static values = { seconds: Number }

  connect() {
    this.remaining = this.secondsValue
    this.render()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() { clearInterval(this.timer) }

  tick() {
    this.remaining -= 1
    if (this.remaining <= 0) {
      clearInterval(this.timer)
      this.labelTarget.textContent = ""
      this.actionTarget.classList.remove("hidden")
    } else {
      this.render()
    }
  }

  render() {
    const mm = String(Math.floor(this.remaining / 60)).padStart(2, "0")
    const ss = String(this.remaining % 60).padStart(2, "0")
    this.labelTarget.textContent = `Reenviar código em ${mm}:${ss}`
  }
}
