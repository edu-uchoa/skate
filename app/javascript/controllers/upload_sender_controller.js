import { Controller } from "@hotwired/stimulus"
import { pending, remove, send } from "lib/upload_queue"

// Tela de envio do vídeo (recordings/_sending): manda os vídeos da fila deste aparelho,
// um de cada vez, com o anel enchendo conforme o upload. Sem internet, espera e tenta
// de novo sozinha quando a conexão volta (evento "online").
export default class extends Controller {
  static targets = [ "ring", "ringFill", "icon", "percent", "counter", "title", "message", "errors", "next", "retry", "again" ]
  static values = { owner: String, url: String, autostart: Boolean, state: String }

  connect() {
    if (this.autostartValue) this.start()
  }

  async start() {
    if (this.running) return
    this.element.hidden = false
    this.running = true
    try {
      await this.sendAll()
    } finally {
      this.running = false
    }
  }

  wentOffline() {
    if (!this.running && this.stateValue !== "done") this.showOffline()
  }

  async sendAll() {
    let items = await pending(this.ownerValue)
    if (items.length === 0) return this.stateValue === "done" ? null : this.showEmpty()
    if (!navigator.onLine) return this.showOffline(items.length)

    const total = items.length
    let lastRedirect = null

    for (const [ index, item ] of items.entries()) {
      this.showUploading(index + 1, total, 0)
      let result
      try {
        result = await send(item, { url: this.urlValue, onProgress: (ratio) => this.showUploading(index + 1, total, ratio) })
      } catch (_error) {
        return this.showOffline(total - index) // caiu a conexão: o vídeo continua guardado
      }

      if (result.status === 201) {
        await remove(item.id)
        lastRedirect = result.body.redirect_url
      } else if (result.status === 422) {
        await remove(item.id) // o servidor recusou (ex.: formato): guardar não adianta
        return this.showRefused(result.body.errors || [])
      } else if (result.status === 410) {
        continue // já não estava mais guardado
      } else {
        return this.showProblem(result.status)
      }
    }

    items = await pending(this.ownerValue)
    if (items.length > 0) return this.sendAll() // chegou outro enquanto enviava
    this.showDone(total, lastRedirect)
  }

  // --- Estados da tela -------------------------------------------------------

  showUploading(position, total, ratio) {
    const percent = Math.round(ratio * 100)
    this.setState("uploading", {
      icon: "cloud_upload", percent: `${percent}%`, ring: percent,
      counter: total > 1 ? `Vídeo ${position} de ${total}` : "Enviando",
      title: percent < 100 ? "Enviando seu vídeo…" : "Quase lá…",
      message: percent < 100 ? "Pode deixar o app aberto. Se a internet cair, o vídeo fica guardado e vai depois."
                             : "O vídeo chegou. Agora estamos protegendo e salvando (tiramos a localização dele)."
    })
  }

  showOffline(count = 1) {
    this.setState("offline", {
      icon: "wifi_off", percent: "", ring: 0, counter: "Sem internet",
      title: count > 1 ? `${count} vídeos guardados no aparelho` : "Vídeo guardado no aparelho",
      message: "Assim que a internet voltar, o envio começa sozinho. Pode deixar o app aberto ou voltar depois: o FlipaAi avisa no topo da tela.",
      retry: true
    })
  }

  showDone(total, redirectUrl) {
    this.setState("done", {
      icon: "check", percent: "", ring: 100, counter: "Enviado",
      title: total > 1 ? "Vídeos enviados com sucesso!" : "Vídeo enviado com sucesso!",
      message: "Já está na fila do mentor, e a devolutiva chega em até 48h. Agora conte como foi o treino.",
      next: total > 1 ? null : redirectUrl, again: true
    })
    if (total > 1) {
      this.nextTarget.textContent = "Ver na Zine"
      this.nextTarget.hidden = false
    }
  }

  showRefused(errors) {
    this.setState("error", {
      icon: "error", percent: "", ring: 0, counter: "Não enviado",
      title: "Esse vídeo não deu para enviar",
      message: "Grave de novo ou escolha outro arquivo.", errors, again: true
    })
  }

  showProblem(status) {
    this.setState("error", {
      icon: "sync_problem", percent: "", ring: 0, counter: "Não enviado",
      title: "Não deu para enviar agora",
      message: status === 200 || status === 401
        ? "Parece que você saiu da conta. Entre de novo: o vídeo continua guardado neste aparelho."
        : `O servidor não respondeu direito (erro ${status}). O vídeo continua guardado; tente de novo daqui a pouco.`,
      retry: true
    })
  }

  showEmpty() {
    this.setState("empty", {
      icon: "check", percent: "", ring: 100, counter: "Tudo certo",
      title: "Nenhum vídeo esperando envio",
      message: "Tudo o que você gravou já chegou ao FlipaAi.", again: true
    })
  }

  setState(state, { icon, percent, ring, counter, title, message, errors = [], retry = false, next = null, again = false }) {
    this.stateValue = state
    this.iconTarget.textContent = icon
    this.percentTarget.textContent = percent
    this.ringFillTarget.style.strokeDashoffset = 100 - ring
    this.ringFillTarget.style.opacity = ring > 0 ? 1 : 0 // vazio: sem a bolinha da ponta
    this.ringTarget.setAttribute("aria-valuenow", ring)
    this.counterTarget.textContent = counter
    this.titleTarget.textContent = title
    this.messageTarget.textContent = message
    this.errorsTarget.replaceChildren(...errors.map((text) => Object.assign(document.createElement("li"), { textContent: text })))
    this.errorsTarget.hidden = errors.length === 0
    this.retryTarget.hidden = !retry
    this.againTarget.hidden = !again
    if (next) this.nextTarget.href = next
    this.nextTarget.hidden = !next
  }
}
