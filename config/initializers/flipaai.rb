Rails.application.configure do
  config.x.flipaai = ActiveSupport::OrderedOptions.new
  config.x.flipaai.support_whatsapp = ENV.fetch("FLIPAAI_SUPPORT_WHATSAPP", "5561999999999")
  config.x.flipaai.minimum_age      = 13
  # Vídeos: a câmera do app para sozinha em max_clip_seconds; depois, na barra de corte,
  # a pessoa escolhe o trecho (até TrainingSession::CLIP_CUT_SECONDS) que é guardado.
  # max_clip_bytes é só um teto de segurança (um arquivo gigante travaria o servidor):
  # o trecho é guardado em 720p (TranscodeClipJob), então o que fica é pequeno.
  config.x.flipaai.max_clip_seconds = 40
  config.x.flipaai.max_clip_bytes   = 500.megabytes
  # ffmpeg limpa a localização (GPS) dos vídeos antes de guardar (ClipSanitizer).
  config.x.flipaai.ffmpeg_path      = ENV.fetch("FFMPEG_PATH", "ffmpeg")
  # Mapa de Picos (Google Maps). A chave vai para o navegador (é assim no Google
  # Maps): restrinja no Google Cloud aos endereços do app. Veja o README.
  config.x.flipaai.google_maps_key    = ENV["GOOGLE_MAPS_API_KEY"]
  config.x.flipaai.google_maps_map_id = ENV.fetch("GOOGLE_MAPS_MAP_ID", "DEMO_MAP_ID")
  config.x.flipaai.map_center         = [ -15.7939, -47.8828 ] # Brasília (DF), enquanto a localização não chega
  config.x.flipaai.spots_file         = Rails.root.join("config/picos.yml") # picos fixos do mapa
  # Entrar com o Google (OmniAuth, config/initializers/omniauth.rb). O ID e o segredo
  # vêm do Google Cloud (veja o README) e ficam em variáveis de ambiente, nunca no código.
  config.x.flipaai.google_client_id     = ENV["GOOGLE_CLIENT_ID"]
  config.x.flipaai.google_client_secret = ENV["GOOGLE_CLIENT_SECRET"]
  # Super administrador: não é configurado aqui. Só o dono concede, com uma assinatura
  # feita na máquina dele (app/models/super_admin.rb e bin/rails super_admin:conceder).
  # Análise automática do vídeo (IA ou reconhecimento corporal). Desligada: hoje o
  # vídeo fica na fila do mentor. Só ligue depois de implementar Ai::FallAnalyzer#call.
  config.x.flipaai.automatic_review = false
end
