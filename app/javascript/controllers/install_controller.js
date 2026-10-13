import { Controller } from "@hotwired/stimulus"

// Página "Instale o Stance" (/instalar). Descobre o aparelho da pessoa e abre o passo
// a passo dele. No Android, o botão instala com um toque (o aviso do navegador fica
// guardado em application.js, porque chega uma vez só, logo ao abrir o app). No
// iPhone não existe esse botão: a Apple só deixa instalar pelo Compartilhar do Safari.
export default class extends Controller {
  static targets = ["button", "standalone", "added", "inApp", "platform"]

  connect() {
    this.refresh = this.refresh.bind(this)
    this.added = this.added.bind(this)
    document.addEventListener("stance:installable", this.refresh)
    document.addEventListener("stance:installed", this.added)

    const platform = this.platform()
    this.platformTargets.forEach((details) => {
      const mine = details.dataset.platform === platform
      details.open = mine
      details.classList.toggle("is-mine", mine)
    })
    this.refresh()
  }

  disconnect() {
    document.removeEventListener("stance:installable", this.refresh)
    document.removeEventListener("stance:installed", this.added)
  }

  async install() {
    const prompt = window.stanceInstallPrompt
    if (!prompt) return

    prompt.prompt()
    const { outcome } = await prompt.userChoice
    window.stanceInstallPrompt = null
    outcome === "accepted" ? this.added() : this.refresh()
  }

  added() {
    this.addedTarget.hidden = false
    this.buttonTarget.hidden = true
  }

  refresh() {
    const standalone = document.documentElement.classList.contains("is-standalone")
    this.standaloneTarget.hidden = !standalone
    this.inAppTarget.hidden = standalone || !this.inAppBrowser()
    this.buttonTarget.hidden = standalone || !window.stanceInstallPrompt
  }

  platform() {
    const agent = navigator.userAgent
    // O iPad novo se apresenta como computador da Apple, mas tem tela de toque.
    if (/iPhone|iPad|iPod/.test(agent) || (/Macintosh/.test(agent) && navigator.maxTouchPoints > 1)) return "ios"
    if (/Android/.test(agent)) return "android"
    return "desktop"
  }

  // Navegador de dentro de outro app (Instagram, Facebook, TikTok...): não instala.
  inAppBrowser() {
    return /FBAN|FBAV|FB_IAB|Instagram|TikTok|musical_ly|Snapchat|LinkedInApp|Line\/|; wv\)/.test(navigator.userAgent)
  }
}
