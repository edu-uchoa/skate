// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// App instalado na tela do celular (PWA). O service worker deixa o app abrir mais
// rápido e mostra "Sem sinal" quando falta internet (app/views/pwa/service-worker.js).
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => navigator.serviceWorker.register("/service-worker.js").catch(() => {}))
}

// Já está aberto como app (fora do navegador)? Some o que convida a instalar.
const standalone = window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
document.documentElement.classList.toggle("is-standalone", standalone)

// O Android (Chrome, Edge, Samsung Internet) avisa quando dá para instalar com um
// toque. O aviso chega uma vez só, logo ao abrir: fica guardado para o botão da
// página /instalar (install_controller.js).
window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault()
  window.stanceInstallPrompt = event
  document.dispatchEvent(new CustomEvent("stance:installable"))
})

window.addEventListener("appinstalled", () => {
  window.stanceInstallPrompt = null
  document.dispatchEvent(new CustomEvent("stance:installed"))
})
