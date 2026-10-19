import { Controller } from "@hotwired/stimulus"

// Libera os botões só quando todos os itens do checklist de segurança estão marcados,
// e mostra o aviso "marque os itens" enquanto falta algum.
export default class extends Controller {
  static targets = ["item", "submit", "label", "hint"]

  connect() { this.refresh() }

  refresh() {
    const complete = this.itemTargets.every((item) => item.checked)
    this.submitTargets.forEach((button) => { button.disabled = !complete })
    if (this.hasHintTarget) this.hintTarget.hidden = complete
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = complete ? "Iniciar treino" : "Complete o checklist"
    }
  }
}
