import { Controller } from "@hotwired/stimulus"
import { clear, pending } from "lib/upload_queue"

// Aviso do topo (layout): sobrou vídeo guardado neste aparelho esperando envio (a pessoa
// fechou o app sem internet). Leva para a tela de envio, que manda sozinha.
// Também apaga a fila desta conta quando ela é apagada ("Apagar minha conta").
export default class extends Controller {
  static targets = [ "label" ]
  static values = { owner: String }

  async connect() {
    if (!this.hasLabelTarget) return // só apaga a fila (tela Apagar minha conta)
    // A tela de envio já está aberta: o aviso seria repetido.
    if (document.querySelector("[data-controller~='upload-sender']:not([hidden])")) return

    const items = await pending(this.ownerValue)
    if (items.length === 0) return

    this.labelTarget.textContent = items.length > 1
      ? `${items.length} vídeos esperando para enviar`
      : "1 vídeo esperando para enviar"
    this.element.hidden = false
  }

  // "Apagar minha conta": tira do aparelho os vídeos desta conta que ainda não subiram.
  async clearAll() {
    await clear(this.ownerValue)
  }
}
