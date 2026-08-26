import { Controller } from "@hotwired/stimulus"

// Libera o botão só quando todos os itens do checklist de segurança estão marcados.
export default class extends Controller {
  static targets = ["item", "submit", "label"]

  connect() { this.refresh() }

  refresh() {
    const complete = this.itemTargets.every((item) => item.checked)
    this.submitTarget.disabled = !complete
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = complete ? "Iniciar treino" : "Complete o checklist"
    }
  }
}
