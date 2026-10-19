// Fila de vídeos para enviar, guardada no próprio celular (IndexedDB) para não perder
// o vídeo quando a internet cai. Usada pela tela Gravar, pela tela de envio
// (upload_sender_controller) e pelo aviso do topo (pending_upload_controller).
//
// Proteções, além das do servidor (login, token CSRF, ClipSanitizer tirando GPS e data):
// - o vídeo fica criptografado (AES-GCM 256) com uma chave que o navegador não deixa
//   ninguém exportar, nem o próprio app;
// - cada vídeo é amarrado à conta (owner): outra pessoa que entrar no mesmo celular não
//   vê nem envia;
// - nome de arquivo genérico ("video.webm") na fila e no envio;
// - assim que o servidor confirma, o vídeo sai do celular.
//
// Sem IndexedDB ou sem criptografia (navegador antigo, aba anônima ou endereço sem
// https), a fila fica só na memória da página: sobrevive à troca de tela, mas não a
// fechar o app.

const DB_NAME = "flipaai-envios"
const DB_VERSION = 1
const CHUNK = 4 * 1024 * 1024 // criptografa em pedaços: vídeo grande não estoura a memória
const EXTENSIONS = { "video/mp4": "mp4", "video/quicktime": "mov", "video/webm": "webm", "video/x-m4v": "m4v" }

const memoryQueue = [] // plano B, só enquanto a página estiver aberta
let dbPromise = null

export const supportsDeviceStorage = () => Boolean(window.indexedDB && window.crypto?.subtle)

// --- Banco no aparelho -------------------------------------------------------

function openDB() {
  if (dbPromise) return dbPromise
  dbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION)
    request.onupgradeneeded = () => {
      const db = request.result
      if (!db.objectStoreNames.contains("uploads")) db.createObjectStore("uploads", { keyPath: "id" })
      if (!db.objectStoreNames.contains("keys")) db.createObjectStore("keys")
    }
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
  return dbPromise
}

function tx(storeName, mode, run) {
  return openDB().then((db) => new Promise((resolve, reject) => {
    const transaction = db.transaction(storeName, mode)
    const result = run(transaction.objectStore(storeName))
    // Leitura (get/getAll) devolve um pedido: o valor fica em .result (undefined se não achou).
    transaction.oncomplete = () => resolve(result instanceof IDBRequest ? result.result : result)
    transaction.onerror = () => reject(transaction.error)
    transaction.onabort = () => reject(transaction.error)
  }))
}

// Chave do aparelho: criada uma vez, não exportável (só serve aqui, neste navegador).
async function deviceKey() {
  const saved = await tx("keys", "readonly", (store) => store.get("upload-key"))
  if (saved) return saved
  const key = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"])
  await tx("keys", "readwrite", (store) => store.put(key, "upload-key"))
  return key
}

async function encrypt(file) {
  const key = await deviceKey()
  const chunks = []
  for (let offset = 0; offset < file.size; offset += CHUNK) {
    const iv = crypto.getRandomValues(new Uint8Array(12))
    const plain = await file.slice(offset, offset + CHUNK).arrayBuffer()
    chunks.push({ iv, data: await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, plain) })
  }
  return chunks
}

async function decrypt(chunks, type) {
  const key = await deviceKey()
  const parts = []
  for (const { iv, data } of chunks) parts.push(await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, data))
  return new Blob(parts, { type })
}

// --- Fila --------------------------------------------------------------------

function genericName(type) {
  return `video.${EXTENSIONS[(type || "").split(";")[0]] || "mp4"}`
}

// Guarda o vídeo e os campos do formulário (fields: lista de pares [nome, valor]).
// Devolve { id, stored: "device" | "memory" }.
export async function enqueue({ owner, file, fields }) {
  const item = {
    id: `${Date.now()}-${crypto.getRandomValues(new Uint32Array(1))[0]}`,
    owner, fields, createdAt: Date.now(),
    type: (file.type || "video/mp4").split(";")[0], size: file.size
  }

  if (supportsDeviceStorage()) {
    try {
      const chunks = await encrypt(file)
      await tx("uploads", "readwrite", (store) => store.put({ ...item, chunks }))
      return { id: item.id, stored: "device" }
    } catch (error) {
      console.warn("[FlipaAi] não deu para guardar o vídeo no aparelho; fica só nesta página", error)
    }
  }
  memoryQueue.push({ ...item, file })
  return { id: item.id, stored: "memory" }
}

// Vídeos esperando envio desta conta, do mais antigo para o mais novo.
export async function pending(owner) {
  let saved = []
  if (supportsDeviceStorage()) {
    try {
      saved = await tx("uploads", "readonly", (store) => store.getAll())
    } catch (_error) {
      saved = []
    }
  }
  return [ ...saved, ...memoryQueue ]
    .filter((item) => item.owner === owner)
    .sort((a, b) => a.createdAt - b.createdAt)
    .map(({ chunks, file, ...meta }) => meta)
}

export async function remove(id) {
  const index = memoryQueue.findIndex((item) => item.id === id)
  if (index >= 0) memoryQueue.splice(index, 1)
  if (supportsDeviceStorage()) {
    try { await tx("uploads", "readwrite", (store) => store.delete(id)) } catch (_error) { /* já não estava */ }
  }
}

// Apaga do aparelho tudo o que é desta conta (ex.: "Apagar minha conta").
export async function clear(owner) {
  for (const item of await pending(owner)) await remove(item.id)
}

// O arquivo de volta, para enviar.
async function fileFor(id) {
  const inMemory = memoryQueue.find((item) => item.id === id)
  if (inMemory) return inMemory.file
  const saved = await tx("uploads", "readonly", (store) => store.get(id))
  return saved ? decrypt(saved.chunks, saved.type) : null
}

// --- Envio -------------------------------------------------------------------

// Envia um vídeo da fila para o servidor, com o login e o token CSRF da página.
// onProgress(0..1). Resolve com { status, body }; rejeita quando cai a conexão.
export async function send(item, { url, onProgress }) {
  const file = await fileFor(item.id)
  if (!file) return { status: 410, body: {} }

  const data = new FormData()
  // fields: pares [nome, valor] na ordem do formulário (o checklist manda "0" e "1"
  // com o mesmo nome, e o Rails fica com o último).
  for (const [ name, value ] of item.fields) data.append(name, value)
  data.set("recording[clip]", file, genericName(item.type))

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open("POST", url)
    xhr.setRequestHeader("Accept", "application/json")
    xhr.setRequestHeader("X-CSRF-Token", document.querySelector("meta[name='csrf-token']")?.content || "")
    xhr.upload.onprogress = (event) => { if (event.lengthComputable) onProgress?.(event.loaded / event.total) }
    xhr.onload = () => {
      let body = {}
      try { body = JSON.parse(xhr.responseText) } catch (_error) { body = {} }
      resolve({ status: xhr.status, body })
    }
    xhr.onerror = () => reject(new Error("offline"))
    xhr.ontimeout = () => reject(new Error("offline"))
    xhr.send(data)
  })
}
