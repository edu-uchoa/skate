import { Controller } from "@hotwired/stimulus"

// Barra de corte da tela Gravar: a pessoa escolhe o trecho do vídeo (até maxSeconds)
// que vai para o mentor. Arrasta as bordas (começo e fim) ou o meio (o trecho inteiro);
// o vídeo de cima mostra o ponto arrastado e o play toca só o trecho.
//
// Quem corta de verdade é o servidor (ClipSanitizer), pelos campos cut_from e cut_to.
// A tela Gravar (recorder_controller) chama load() quando um vídeo novo entra.
const MIN_SECONDS = 1   // o trecho mais curto
const KEY_STEP = 0.5    // setas do teclado nas bordas; com Shift, BIG_KEY_STEP
const BIG_KEY_STEP = 2

export default class extends Controller {
  static targets = [
    "video", "editor", "fallback", "track", "range", "startHandle", "endHandle", "playhead",
    "playButton", "playIcon", "length", "from", "to", "duration", "cutFrom", "cutTo"
  ]
  static values = { maxSeconds: Number }

  connect() {
    this.duration = 0
  }

  disconnect() {
    cancelAnimationFrame(this.watching)
  }

  // Vídeo novo na pré-visualização. duration: a que a tela Gravar já sabe (cronômetro da
  // câmera ou metadados do arquivo), para quando o navegador não consegue ler a do vídeo.
  async load(duration) {
    this.reset()
    const loading = (this.loading = {})
    const real = (await readDuration(this.videoTarget)) || duration
    if (loading !== this.loading) return // chegou outro vídeo (ou foi descartado) enquanto lia

    if (!(real > 0)) {
      // Sem a duração não dá para desenhar a barra (o vídeo fica com os controles normais):
      // o servidor guarda os primeiros segundos.
      this.fallbackTarget.hidden = false
      return
    }

    this.duration = real
    this.start = 0
    this.end = Math.min(real, this.maxSecondsValue)
    this.durationTarget.value = real.toFixed(2)
    this.videoTarget.controls = false // o play e a linha do tempo passam a ser os da barra
    this.editorTarget.hidden = false
    this.render()
  }

  reset() {
    this.loading = null
    this.duration = 0
    this.dragging = null
    this.videoTarget.pause()
    this.videoTarget.controls = true
    this.editorTarget.hidden = true
    this.fallbackTarget.hidden = true
    this.cutFromTarget.value = ""
    this.cutToTarget.value = ""
  }

  // --- Arrastar ---------------------------------------------------------------

  // Tocou na barra: numa borda (alça amarela), no meio (move o trecho inteiro) ou fora
  // do trecho (a borda mais perto vem até ali).
  grab(event) {
    if (!this.duration || event.button > 0) return
    event.preventDefault()
    const time = this.timeAt(event.clientX)
    const edge = event.target.closest("[data-edge]")?.dataset.edge

    if (edge) {
      this.dragging = { edge }
    } else if (event.target === this.rangeTarget) {
      this.dragging = { edge: "range", offset: time - this.start }
    } else {
      this.dragging = { edge: Math.abs(time - this.start) <= Math.abs(time - this.end) ? "start" : "end" }
      this.move(time)
    }

    this.videoTarget.pause()
    this.trackTarget.setPointerCapture?.(event.pointerId)
    this.trackTarget.classList.add("is-dragging")
  }

  drag(event) {
    if (!this.dragging) return
    this.move(this.timeAt(event.clientX) - (this.dragging.offset || 0))
  }

  drop() {
    if (!this.dragging) return
    this.dragging = null
    this.trackTarget.classList.remove("is-dragging")
  }

  // Teclado, com a borda em foco: setas andam meio segundo (com Shift, 2s); Home e End
  // vão para o começo e o fim do vídeo.
  nudge(event) {
    if (!this.duration) return
    const edge = event.currentTarget.dataset.edge
    const now = edge === "start" ? this.start : this.end
    const step = event.shiftKey ? BIG_KEY_STEP : KEY_STEP
    const time = {
      ArrowLeft: now - step, ArrowDown: now - step, PageDown: now - BIG_KEY_STEP,
      ArrowRight: now + step, ArrowUp: now + step, PageUp: now + BIG_KEY_STEP,
      Home: 0, End: this.duration
    }[event.key]
    if (time === undefined) return
    event.preventDefault()
    this.move(time, edge)
  }

  // Leva a borda (ou o trecho inteiro) até o tempo pedido, com o mínimo de MIN_SECONDS.
  // Passando do máximo, a outra borda vem junto.
  move(time, edge = this.dragging.edge) {
    const shortest = Math.min(MIN_SECONDS, this.duration)
    const longest = Math.min(this.maxSecondsValue, this.duration)
    let { start, end } = this

    if (edge === "start") {
      start = clamp(time, 0, end - shortest)
      end = Math.min(end, start + longest)
    } else if (edge === "end") {
      end = clamp(time, start + shortest, this.duration)
      start = Math.max(start, end - longest)
    } else {
      const length = end - start
      start = clamp(time, 0, this.duration - length)
      end = start + length
    }

    this.start = start
    this.end = end
    this.render()
    this.showFrame(edge === "end" ? end : start)
  }

  timeAt(clientX) {
    const box = this.trackTarget.getBoundingClientRect()
    return clamp((clientX - box.left) / box.width, 0, 1) * this.duration
  }

  // Mostra no vídeo o ponto arrastado (no máximo uma busca por quadro da tela).
  showFrame(time) {
    this.frameTime = time
    if (this.seekQueued) return
    this.seekQueued = true
    requestAnimationFrame(() => {
      this.seekQueued = false
      this.videoTarget.currentTime = this.frameTime
    })
  }

  // --- Tocar só o trecho ------------------------------------------------------

  // Botão de play ou toque no vídeo: toca o trecho a partir do começo dele.
  togglePlay() {
    if (!this.duration) return
    const video = this.videoTarget
    if (!video.paused) return video.pause()
    if (video.currentTime < this.start || video.currentTime >= this.end - 0.05) video.currentTime = this.start
    video.play()?.catch(() => {})
  }

  played() {
    if (!this.duration) return
    this.playIconTarget.textContent = "pause"
    this.playButtonTarget.setAttribute("aria-label", "Pausar")
    this.watch()
  }

  paused() {
    this.playIconTarget.textContent = "play_arrow"
    this.playButtonTarget.setAttribute("aria-label", "Tocar o trecho")
    cancelAnimationFrame(this.watching)
  }

  // Tocando: no fim do trecho, para e volta para o começo dele.
  watch() {
    const video = this.videoTarget
    if (video.currentTime >= this.end) {
      video.pause()
      video.currentTime = this.start
    }
    this.renderPlayhead()
    if (!video.paused) this.watching = requestAnimationFrame(() => this.watch())
  }

  // --- Tela -------------------------------------------------------------------

  render() {
    const percent = (seconds) => `${(seconds / this.duration) * 100}%`
    this.rangeTarget.style.left = percent(this.start)
    this.rangeTarget.style.width = percent(this.end - this.start)
    this.trackTarget.style.setProperty("--trim-tick", percent(tickSeconds(this.duration)))
    this.lengthTarget.textContent = `${decimal(this.end - this.start)}s`
    this.fromTarget.textContent = clock(this.start)
    this.toTarget.textContent = clock(this.end)
    this.describe(this.startHandleTarget, this.start)
    this.describe(this.endHandleTarget, this.end)
    this.cutFromTarget.value = this.start.toFixed(2)
    this.cutToTarget.value = this.end.toFixed(2)
    this.renderPlayhead()
  }

  renderPlayhead() {
    if (!this.duration) return
    const time = Math.min(this.videoTarget.currentTime, this.duration)
    this.playheadTarget.style.left = `${(time / this.duration) * 100}%`
  }

  // Leitor de tela: em que segundo está cada borda.
  describe(handle, seconds) {
    handle.setAttribute("aria-valuemin", "0")
    handle.setAttribute("aria-valuemax", this.duration.toFixed(1))
    handle.setAttribute("aria-valuenow", seconds.toFixed(1))
    handle.setAttribute("aria-valuetext", `${decimal(seconds)} segundos`)
  }
}

// Duração do vídeo da pré-visualização. O WebM gravado no Chrome não traz a duração
// (o navegador diz "Infinity"): pulando para o fim, ele descobre. null se não der em 5s.
function readDuration(video) {
  return new Promise((resolve) => {
    let jumped = false
    const check = () => {
      if (Number.isFinite(video.duration) && video.duration > 0) return finish(video.duration)
      if (video.readyState >= 1 && !jumped) {
        jumped = true
        video.currentTime = 1e101
      }
    }
    const finish = (value) => {
      clearTimeout(timer)
      video.removeEventListener("loadedmetadata", check)
      video.removeEventListener("durationchange", check)
      if (jumped) video.currentTime = 0
      resolve(value)
    }
    const timer = setTimeout(() => finish(null), 5000)
    video.addEventListener("loadedmetadata", check)
    video.addEventListener("durationchange", check)
    check()
  })
}

const clamp = (value, min, max) => Math.min(Math.max(value, min), max)

// Uma marquinha por segundo na barra; em vídeo longo, no máximo 40 marquinhas.
const tickSeconds = (duration) => Math.max(1, Math.ceil(duration / 40))

const decimal = (seconds) => seconds.toFixed(1).replace(".", ",")

// 0:03,2 (minutos:segundos,décimos)
function clock(seconds) {
  const tenths = Math.round(seconds * 10)
  const rest = ((tenths % 600) / 10).toFixed(1).padStart(4, "0")
  return `${Math.floor(tenths / 600)}:${rest.replace(".", ",")}`
}
