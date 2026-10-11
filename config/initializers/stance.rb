Rails.application.configure do
  config.x.stance = ActiveSupport::OrderedOptions.new
  config.x.stance.support_whatsapp = ENV.fetch("STANCE_SUPPORT_WHATSAPP", "5561999999999")
  config.x.stance.minimum_age      = 13
  config.x.stance.max_clip_seconds = 15
  config.x.stance.max_clip_bytes   = 40.megabytes
  # ffmpeg limpa a localização (GPS) dos vídeos antes de guardar (ClipSanitizer).
  config.x.stance.ffmpeg_path      = ENV.fetch("FFMPEG_PATH", "ffmpeg")
  # Mapa de Picos (Google Maps). A chave vai para o navegador (é assim no Google
  # Maps): restrinja no Google Cloud aos endereços do app. Veja o README.
  config.x.stance.google_maps_key    = ENV["GOOGLE_MAPS_API_KEY"]
  config.x.stance.google_maps_map_id = ENV.fetch("GOOGLE_MAPS_MAP_ID", "DEMO_MAP_ID")
  config.x.stance.map_center         = [ -15.7939, -47.8828 ] # Brasília (DF), enquanto a localização não chega
  config.x.stance.spots_file         = Rails.root.join("config/picos.yml") # picos fixos do mapa
  # Análise automática do vídeo (IA ou reconhecimento corporal). Desligada: hoje o
  # vídeo fica na fila do mentor. Só ligue depois de implementar Ai::FallAnalyzer#call.
  config.x.stance.automatic_review = false
end
