import { Controller } from "@hotwired/stimulus"

// Compartilhar um rolê com os amigos: a janela de compartilhar do celular
// (WhatsApp, Instagram...) ou, onde ela não existe, o WhatsApp direto.
export default class extends Controller {
  static targets = ["copyButton"]
  static values = { url: String, text: String }

  async share() {
    if (navigator.share) {
      try {
        await navigator.share({ title: "Bora andar de skate?", text: this.textValue, url: this.urlValue })
        return
      } catch (error) {
        if (error.name === "AbortError") return // a pessoa fechou a janela
      }
    }
    window.open(`https://wa.me/?text=${encodeURIComponent(`${this.textValue} ${this.urlValue}`)}`, "_blank", "noopener")
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.urlValue)
      this.copyButtonTarget.textContent = "Link copiado!"
    } catch {
      window.prompt("Copie o link do rolê:", this.urlValue)
    }
  }
}
