import { Controller } from "@hotwired/stimulus"

// Tela do nickname: mostra na hora como a pessoa vai aparecer ("skatista#0420").
// Sem número digitado, mostra o sugerido (o app sorteia um livre ao salvar).
export default class extends Controller {
  static targets = ["name", "tag", "preview"]
  static values = { fallback: String }

  preview() {
    const name = this.nameTarget.value.trim() || this.fallbackValue
    const tag = this.tagTarget.value.trim() || this.tagTarget.placeholder
    this.previewTarget.textContent = `${name}#${tag}`
  }
}
