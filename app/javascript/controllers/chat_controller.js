import { Controller } from "@hotwired/stimulus"

// Chat entre aprendiz e mentores (chats/_thread). Mostra a última mensagem e, a
// cada poucos segundos, pergunta ao servidor se chegou alguma nova; a resposta é um
// turbo-stream que acrescenta só as novas (o Turbo não repete uma que já está na tela).
export default class extends Controller {
  static targets = ["list"]
  static values = { url: String, interval: { type: Number, default: 6000 } }

  connect() {
    this.scrollToEnd()
    this.observer = new MutationObserver(() => this.scrollToEnd())
    this.observer.observe(this.listTarget, { childList: true })
    this.timer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
    this.observer?.disconnect()
  }

  async poll() {
    if (document.visibilityState !== "visible" || this.polling) return

    this.polling = true
    try {
      const response = await fetch(`${this.urlValue}?depois=${this.lastId}`, {
        headers: { Accept: "text/vnd.turbo-stream.html" }
      })
      if (response.status === 200) window.Turbo.renderStreamMessage(await response.text())
    } catch {
      // Sem internet: tenta de novo na próxima volta.
    } finally {
      this.polling = false
    }
  }

  get lastId() {
    const messages = this.listTarget.querySelectorAll("[data-message-id]")
    return messages.length ? messages[messages.length - 1].dataset.messageId : 0
  }

  scrollToEnd() {
    this.listTarget.scrollTop = this.listTarget.scrollHeight
  }
}
