import { Controller } from "@hotwired/stimulus"

// Recarrega a página de espera até a devolutiva da IA ficar pronta.
// Não recarrega enquanto um vídeo da página estiver tocando.
export default class extends Controller {
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.timer = setInterval(() => {
      const playing = [...document.querySelectorAll("video")].some((video) => !video.paused && !video.ended)
      if (document.visibilityState === "visible" && !playing) {
        window.Turbo ? Turbo.visit(window.location.href, { action: "replace" }) : window.location.reload()
      }
    }, this.intervalValue)
  }

  disconnect() { clearInterval(this.timer) }
}
