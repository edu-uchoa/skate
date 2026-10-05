Rails.application.configure do
  config.x.stance = ActiveSupport::OrderedOptions.new
  config.x.stance.support_whatsapp = ENV.fetch("STANCE_SUPPORT_WHATSAPP", "5561999999999")
  config.x.stance.minimum_age      = 13
  config.x.stance.max_clip_seconds = 15
  config.x.stance.max_clip_bytes   = 40.megabytes
  # ffmpeg limpa a localização (GPS) dos vídeos antes de guardar (ClipSanitizer).
  config.x.stance.ffmpeg_path      = ENV.fetch("FFMPEG_PATH", "ffmpeg")
  # Análise automática do vídeo (IA ou reconhecimento corporal). Desligada: hoje o
  # vídeo fica na fila do mentor. Só ligue depois de implementar Ai::FallAnalyzer#call.
  config.x.stance.automatic_review = false
end
