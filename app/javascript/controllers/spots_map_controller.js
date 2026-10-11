import { Controller } from "@hotwired/stimulus"

// Mapa de Picos (Google Maps).
//
// A página só funciona com a localização do aparelho liberada: sem ela, mostra
// como liberar. A localização só centraliza o mapa e marca "você está aqui";
// nunca é enviada ao servidor.
//
// Alfinetes: picos fixos em amarelo, rolês da pessoa em laranja, ela em azul.
// Tocar no mapa (ou em "Marcar rolê aqui") abre o formulário com o lugar.
export default class extends Controller {
  static targets = ["asking", "denied", "deniedReason", "content", "map", "unavailable",
                    "form", "latitude", "longitude", "placeName"]
  static values = { apiKey: String, mapId: String, center: Array, spots: Array, meetups: Array }

  connect() {
    this.onAuthFailure = () => this.mapUnavailable()
    document.addEventListener("stance:maps-auth-failure", this.onAuthFailure)
    this.watchPermission()
    this.locate()
  }

  disconnect() {
    document.removeEventListener("stance:maps-auth-failure", this.onAuthFailure)
    if (this.permission) this.permission.onchange = null
  }

  retry() {
    this.locate()
  }

  locate() {
    if (!window.isSecureContext || !("geolocation" in navigator)) {
      return this.deny("Este navegador não libera a localização nesta página. Abra o Stance pelo endereço com https ou pelo app instalado.")
    }

    this.show("asking")
    navigator.geolocation.getCurrentPosition(
      (position) => this.granted(position.coords),
      (error) => this.deny(error.code === error.PERMISSION_DENIED
        ? "Você não liberou a localização. Sem ela, o mapa de picos não funciona."
        : "Não conseguimos achar a sua localização. Confira se a localização do aparelho está ligada e tente de novo."),
      { enableHighAccuracy: false, timeout: 15000, maximumAge: 300000 }
    )
  }

  // Se a pessoa mudar a permissão com a página aberta, a tela acompanha.
  async watchPermission() {
    try {
      this.permission = await navigator.permissions.query({ name: "geolocation" })
      this.permission.onchange = () => this.locate()
    } catch {
      // Navegador sem a API de permissões: o pedido de localização já resolve.
    }
  }

  show(state) {
    this.askingTarget.hidden = state !== "asking"
    this.deniedTarget.hidden = state !== "denied"
    this.contentTarget.hidden = state !== "granted"
  }

  deny(reason) {
    this.deniedReasonTarget.textContent = reason
    this.show("denied")
  }

  async granted(coords) {
    this.position = { lat: coords.latitude, lng: coords.longitude }
    this.show("granted")

    if (this.map) {
      this.me.position = this.position
      return
    }
    if (!this.apiKeyValue) return this.mapUnavailable()

    try {
      await loadGoogleMaps(this.apiKeyValue)
      await this.buildMap()
    } catch {
      this.mapUnavailable()
    }
  }

  mapUnavailable() {
    this.mapTarget.hidden = true
    this.unavailableTarget.hidden = false
  }

  async buildMap() {
    const { Map } = await google.maps.importLibrary("maps")
    const { AdvancedMarkerElement, PinElement } = await google.maps.importLibrary("marker")
    this.Marker = AdvancedMarkerElement
    this.Pin = PinElement

    this.map = new Map(this.mapTarget, {
      center: this.position || { lat: this.centerValue[0], lng: this.centerValue[1] },
      zoom: 13,
      mapId: this.mapIdValue || "DEMO_MAP_ID",
      colorScheme: "DARK",
      disableDefaultUI: true,
      zoomControl: true,
      clickableIcons: false,
      gestureHandling: "greedy"
    })

    const dot = document.createElement("div")
    dot.className = "spots-me"
    this.me = new AdvancedMarkerElement({ map: this.map, position: this.position, title: "Você está aqui", content: dot })

    this.spotsValue.forEach((spot, index) => {
      this.pin(spot, "#ffb800", "#6b4c00", spot.name, () => this.highlight(`spot_${index}`))
    })
    this.meetupsValue.forEach((meetup) => {
      this.pin(meetup, "#fd591e", "#7a2a0b", "Seu rolê", () => this.highlight(`meetup_${meetup.id}`))
    })

    this.map.addListener("click", (event) => this.pickPoint(event.latLng.toJSON()))
  }

  pin({ lat, lng }, background, borderColor, title, onClick) {
    const pin = new this.Pin({ background, borderColor, glyphColor: "#0d0e11" })
    const marker = new this.Marker({ map: this.map, position: { lat, lng }, title, content: pin.element })
    marker.addListener("click", onClick)
    return marker
  }

  // Toque num ponto qualquer do mapa: alfinete branco (dá para arrastar) e formulário.
  pickPoint(position) {
    if (this.draft) {
      this.draft.position = position
    } else {
      const pin = new this.Pin({ background: "#e3e2e6", borderColor: "#0d0e11", glyphColor: "#0d0e11" })
      this.draft = new this.Marker({ map: this.map, position, title: "Rolê aqui", content: pin.element, gmpDraggable: true })
      this.draft.addListener("dragend", () => this.fillForm(this.draft.position))
    }
    this.fillForm(position)
  }

  // "Marcar rolê aqui" num pico fixo.
  pickSpot({ params: { index } }) {
    const spot = this.spotsValue[index]
    if (this.draft) this.draft.map = null
    this.draft = null
    this.map?.panTo({ lat: spot.lat, lng: spot.lng })
    this.fillForm(spot, spot.name)
  }

  fillForm(position, placeName = null) {
    const { lat, lng } = typeof position.lat === "function" ? position.toJSON() : position
    this.latitudeTarget.value = Number(lat).toFixed(6)
    this.longitudeTarget.value = Number(lng).toFixed(6)
    if (placeName) this.placeNameTarget.value = placeName

    this.formTarget.hidden = false
    this.formTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    if (!placeName && !this.placeNameTarget.value) this.placeNameTarget.focus({ preventScroll: true })
  }

  closeForm() {
    this.formTarget.hidden = true
    if (this.draft) this.draft.map = null
    this.draft = null
  }

  highlight(id) {
    const card = document.getElementById(id)
    if (!card) return
    card.scrollIntoView({ behavior: "smooth", block: "center" })
    card.classList.add("is-highlighted")
    setTimeout(() => card.classList.remove("is-highlighted"), 1800)
  }
}

// Carrega o Google Maps uma vez só, mesmo navegando entre páginas com o Turbo.
let googleMaps
function loadGoogleMaps(key) {
  googleMaps ||= new Promise((resolve, reject) => {
    if (window.google?.maps?.importLibrary) return resolve()

    window.stanceGoogleMapsReady = () => resolve()
    // O Google chama esta função quando a chave é inválida ou não vale para este endereço.
    window.gm_authFailure = () => document.dispatchEvent(new CustomEvent("stance:maps-auth-failure"))

    const params = new URLSearchParams({ key, v: "weekly", loading: "async", libraries: "marker",
                                         language: "pt-BR", region: "BR", callback: "stanceGoogleMapsReady" })
    const script = document.createElement("script")
    script.src = `https://maps.googleapis.com/maps/api/js?${params}`
    script.async = true
    script.onerror = () => {
      googleMaps = null
      reject(new Error("O Google Maps não carregou"))
    }
    document.head.append(script)
  })
  return googleMaps
}
