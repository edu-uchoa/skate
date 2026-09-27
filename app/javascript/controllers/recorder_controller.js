import { Controller } from "@hotwired/stimulus"

// Tela "Gravar": grava pela câmera (MediaRecorder) ou escolhe um arquivo,
// mostra a pré-visualização, valida tamanho/duração/formato e envia via
// FormData (multipart) com barra de progresso.
//
// Ordem de preferência na gravação: MP4 (Safari/iOS) e depois WebM (Chrome/Android).
const RECORDING_TYPES = ["video/mp4", "video/webm;codecs=vp9,opus", "video/webm;codecs=vp8,opus", "video/webm"]

const TYPES_BY_EXTENSION = { mp4: "video/mp4", m4v: "video/mp4", mov: "video/quicktime", webm: "video/webm" }

export default class extends Controller {
  static targets = [
    "form", "chooser", "camera", "live", "timer", "recordButton", "recordLabel",
    "preview", "previewVideo", "meta", "fileInput", "captureInput",
    "duration", "source", "check", "progress", "progressBar", "progressLabel", "errors", "submit"
  ]
  static values = { maxSeconds: Number, maxBytes: Number, types: Array }

  connect() {
    this.clip = null
    this.refresh()
  }

  disconnect() {
    this.stopRecording(false)
    this.stopStream()
    this.revokePreview()
  }

  // --- Câmera ---------------------------------------------------------------

  async openCamera() {
    this.clearErrors()

    // Sem API de gravação (ex.: acesso por http fora de localhost): câmera nativa.
    if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) {
      this.captureInputTarget.click()
      return
    }

    try {
      this.stream = await this.requestStream(true)
    } catch (error) {
      this.showErrors([cameraErrorMessage(error)])
      return
    }

    this.liveTarget.srcObject = this.stream
    this.renderTimer(0)
    this.show("camera")
  }

  // Tenta com microfone; se não houver, grava só o vídeo.
  async requestStream(withAudio) {
    const video = { facingMode: "environment", width: { ideal: 1280 }, height: { ideal: 720 } }
    try {
      return await navigator.mediaDevices.getUserMedia({ video, audio: withAudio })
    } catch (error) {
      if (withAudio && error.name !== "NotAllowedError") return this.requestStream(false)
      throw error
    }
  }

  closeCamera() {
    this.stopRecording(false)
    this.stopStream()
    this.show("chooser")
  }

  toggleRecording() {
    this.recorder?.state === "recording" ? this.stopRecording(true) : this.startRecording()
  }

  startRecording() {
    const mimeType = RECORDING_TYPES.find((type) => MediaRecorder.isTypeSupported(type))
    this.chunks = []
    this.recorder = new MediaRecorder(this.stream, mimeType ? { mimeType } : undefined)
    this.recorder.ondataavailable = (event) => { if (event.data.size > 0) this.chunks.push(event.data) }
    this.recorder.onstop = () => this.finishRecording()
    this.keepRecording = true
    this.recorder.start(250)

    this.startedAt = performance.now()
    this.timerId = setInterval(() => {
      const elapsed = (performance.now() - this.startedAt) / 1000
      this.renderTimer(elapsed)
      if (elapsed >= this.maxSecondsValue) this.stopRecording(true)
    }, 200)

    this.recordButtonTarget.classList.add("recording")
    this.recordLabelTarget.textContent = "Parar"
  }

  stopRecording(keep) {
    clearInterval(this.timerId)
    if (this.recorder?.state !== "recording") return

    this.keepRecording = keep
    this.recordedSeconds = Math.min((performance.now() - this.startedAt) / 1000, this.maxSecondsValue)
    this.recorder.stop()
  }

  finishRecording() {
    this.recordButtonTarget.classList.remove("recording")
    this.recordLabelTarget.textContent = "Gravar"
    if (!this.keepRecording) return

    const type = (this.recorder.mimeType || "video/webm").split(";")[0]
    const extension = type === "video/mp4" ? "mp4" : "webm"
    const file = new File(this.chunks, `manobra-${Date.now()}.${extension}`, { type })

    this.stopStream()
    this.useClip(file, "camera", this.recordedSeconds)
  }

  stopStream() {
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
    if (this.hasLiveTarget) this.liveTarget.srcObject = null
  }

  // --- Upload de arquivo ----------------------------------------------------

  pickFile() {
    this.clearErrors()
    this.fileInputTarget.click()
  }

  async fileChosen(event) {
    const input = event.target
    const file = input.files[0]
    input.value = "" // permite escolher o mesmo arquivo de novo depois de descartar
    if (!file) return

    const source = input === this.captureInputTarget ? "camera" : "upload"
    this.useClip(file, source, await readDuration(file))
  }

  // --- Pré-visualização e validação -----------------------------------------

  useClip(file, source, duration) {
    const problems = this.validate(file, duration)
    if (problems.length > 0) {
      this.showErrors(problems)
      this.show("chooser")
      return
    }

    this.clearErrors()
    this.clip = { file, source, duration }
    this.revokePreview()
    this.previewUrl = URL.createObjectURL(file)
    this.previewVideoTarget.src = this.previewUrl

    const parts = [ duration ? `${formatSeconds(duration)}s` : null, formatMegabytes(file.size),
                    source === "camera" ? "Gravado agora" : file.name ].filter(Boolean)
    this.metaTarget.textContent = parts.join(" · ")
    this.durationTarget.value = duration ? duration.toFixed(2) : ""
    this.sourceTarget.value = source

    this.show("preview")
    this.refresh()
  }

  discard() {
    this.clip = null
    this.revokePreview()
    this.previewVideoTarget.removeAttribute("src")
    this.previewVideoTarget.load()
    this.durationTarget.value = ""
    this.sourceTarget.value = ""
    this.show("chooser")
    this.refresh()
  }

  validate(file, duration) {
    const problems = []
    const type = contentTypeOf(file)

    if (!this.typesValue.includes(type)) {
      problems.push("Formato não suportado. Envie MP4, MOV ou WebM.")
    }
    if (file.size > this.maxBytesValue) {
      problems.push(`O vídeo tem ${formatMegabytes(file.size)}; o máximo é ${formatMegabytes(this.maxBytesValue)}.`)
    }
    if (duration && duration > this.maxSecondsValue + 1) {
      problems.push(`O vídeo tem ${Math.round(duration)}s; o máximo é ${this.maxSecondsValue}s. Corte ou grave de novo.`)
    }
    return problems
  }

  refresh() {
    const ready = this.clip && this.checkTargets.every((check) => check.checked)
    this.submitTarget.disabled = !ready || this.uploading
  }

  // --- Envio (multipart) com progresso --------------------------------------

  upload(event) {
    event.preventDefault()
    if (!this.clip || this.uploading) return

    const data = new FormData(this.formTarget)
    data.set("recording[clip]", this.clip.file, this.clip.file.name)

    const xhr = new XMLHttpRequest()
    xhr.open("POST", this.formTarget.action)
    xhr.setRequestHeader("Accept", "application/json")
    xhr.setRequestHeader("X-CSRF-Token", document.querySelector("meta[name='csrf-token']")?.content || "")
    xhr.upload.onprogress = (e) => { if (e.lengthComputable) this.renderProgress(e.loaded / e.total) }
    xhr.onload = () => this.uploaded(xhr)
    xhr.onerror = () => this.failed(["Falha de conexão. Verifique a internet e tente de novo."])

    this.uploading = true
    this.clearErrors()
    this.refresh()
    this.progressTarget.hidden = false
    this.renderProgress(0)
    xhr.send(data)
  }

  uploaded(xhr) {
    const body = parseJSON(xhr.responseText)

    if (xhr.status === 201 && body.redirect_url) {
      this.progressLabelTarget.textContent = "Vídeo salvo!"
      window.Turbo ? window.Turbo.visit(body.redirect_url) : window.location.assign(body.redirect_url)
    } else {
      this.failed(body.errors || [`Não foi possível enviar (erro ${xhr.status}). Tente de novo.`])
    }
  }

  failed(problems) {
    this.uploading = false
    this.progressTarget.hidden = true
    this.showErrors(problems)
    this.refresh()
  }

  renderProgress(ratio) {
    const percent = Math.round(ratio * 100)
    this.progressBarTarget.style.width = `${percent}%`
    this.progressLabelTarget.textContent = percent < 100 ? `Enviando… ${percent}%` : "Salvando vídeo…"
  }

  // --- Helpers de tela ------------------------------------------------------

  show(stage) {
    this.chooserTarget.hidden = stage !== "chooser"
    this.cameraTarget.hidden = stage !== "camera"
    this.previewTarget.hidden = stage !== "preview"
  }

  renderTimer(seconds) {
    const pad = (n) => String(Math.floor(n)).padStart(2, "0")
    this.timerTarget.textContent = `00:${pad(seconds)} / 00:${pad(this.maxSecondsValue)}`
  }

  showErrors(messages) {
    this.errorsTarget.replaceChildren(...messages.map((message) => {
      const item = document.createElement("li")
      item.textContent = message
      return item
    }))
    this.errorsTarget.hidden = false
  }

  clearErrors() {
    this.errorsTarget.replaceChildren()
    this.errorsTarget.hidden = true
  }

  revokePreview() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }
}

// Alguns navegadores (Windows) não informam o tipo de .mov; deduz pela extensão.
function contentTypeOf(file) {
  const type = (file.type || "").split(";")[0]
  if (type) return type
  const extension = file.name.split(".").pop().toLowerCase()
  return TYPES_BY_EXTENSION[extension] || ""
}

// Duração pelos metadados do vídeo; null quando o navegador não consegue ler.
function readDuration(file) {
  return new Promise((resolve) => {
    const video = document.createElement("video")
    const url = URL.createObjectURL(file)
    const done = (value) => {
      clearTimeout(timeout)
      URL.revokeObjectURL(url)
      resolve(Number.isFinite(value) && value > 0 ? value : null)
    }
    const timeout = setTimeout(() => done(null), 5000)
    video.preload = "metadata"
    video.onloadedmetadata = () => done(video.duration)
    video.onerror = () => done(null)
    video.src = url
  })
}

function cameraErrorMessage(error) {
  switch (error?.name) {
    case "NotAllowedError": return "Permita o acesso à câmera nas configurações do navegador."
    case "NotFoundError":   return "Nenhuma câmera encontrada. Use \"Fazer upload de vídeo\"."
    case "NotReadableError": return "A câmera está em uso por outro app. Feche-o e tente de novo."
    default:                return "Não foi possível abrir a câmera. Use \"Fazer upload de vídeo\"."
  }
}

function parseJSON(text) {
  try { return JSON.parse(text) } catch { return {} }
}

function formatSeconds(seconds) {
  return seconds.toFixed(1).replace(".", ",")
}

function formatMegabytes(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(1).replace(".", ",")} MB`
}
