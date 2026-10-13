// Service worker do Stance: o que faz o app instalado na tela do celular abrir
// rápido e avisar quando não há internet. Registrado em app/javascript/application.js.
//
// - Visual do app (/assets: CSS, JavaScript e imagens, com uma impressão digital no
//   nome, então nunca mudam): guardado no celular na primeira vez e servido de lá.
// - Páginas: sempre pela internet e NUNCA guardadas, porque têm dados pessoais e
//   vídeos de menores. Sem internet, aparece a página "Sem sinal" (/offline.html).
// - Vídeos, envios de formulário e o resto: o service worker não mexe.
//
// Mudou /offline.html ou este arquivo? Troque a VERSION para os celulares baixarem de novo.
const VERSION = "stance-v1"
const OFFLINE_URL = "/offline.html"
const SHELL = `${VERSION}-shell`
const ASSETS = `${VERSION}-assets`
const MAX_ASSETS = 80

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(SHELL)
      .then((cache) => cache.addAll([OFFLINE_URL, "/icon-192.png"]))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => !key.startsWith(VERSION)).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET" || request.headers.has("range")) return

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  if (url.pathname.startsWith("/assets/")) {
    event.respondWith(cachedAsset(request))
  } else if (request.mode === "navigate" || request.headers.get("accept")?.includes("text/html")) {
    event.respondWith(fetch(request).catch(offlinePage))
  }
})

async function cachedAsset(request) {
  const cache = await caches.open(ASSETS)
  const cached = await cache.match(request)
  if (cached) return cached

  const response = await fetch(request)
  if (response.status === 200) {
    await cache.put(request, response.clone())
    trim(cache)
  }
  return response
}

// Guarda só os últimos arquivos: versões antigas do visual não ficam ocupando espaço.
async function trim(cache) {
  const keys = await cache.keys()
  const extra = keys.length - MAX_ASSETS
  if (extra > 0) await Promise.all(keys.slice(0, extra).map((key) => cache.delete(key)))
}

// Status 503: o Turbo e o recarregamento da página de espera entendem que falhou.
async function offlinePage() {
  const page = await caches.match(OFFLINE_URL)
  if (!page) return new Response("Sem internet.", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" } })

  return new Response(page.body, { status: 503, statusText: "Offline", headers: page.headers })
}
