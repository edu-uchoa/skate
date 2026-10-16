Rails.application.configure do
  config.x.flipaai = ActiveSupport::OrderedOptions.new
  config.x.flipaai.support_whatsapp = ENV.fetch("FLIPAAI_SUPPORT_WHATSAPP", "5561999999999")
  config.x.flipaai.minimum_age      = 13
  config.x.flipaai.max_clip_seconds = 15
  config.x.flipaai.max_clip_bytes   = 40.megabytes
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
  # LGPD: quem responde pelos dados (controlador) e o e-mail para pedidos de acesso,
  # correção e exclusão. Aparecem na Política de Privacidade e nos Termos de Uso.
  config.x.flipaai.privacy_controller = ENV.fetch("PRIVACY_CONTROLLER", "Caio Lyra")
  config.x.flipaai.privacy_email      = ENV.fetch("PRIVACY_EMAIL", "caiolyrapeixoto@gmail.com")
  config.x.flipaai.legal_updated_on   = Date.new(2026, 10, 17) # data da versão atual dos textos
  # Super administrador (dono do app): as contas Google com estes e-mails, separados por
  # vírgula. Fica só no servidor (Render > Environment): ninguém vira super admin pelo app.
  config.x.flipaai.super_admin_emails = ENV.fetch("SUPER_ADMIN_EMAILS", "").split(",").map { it.strip.downcase }.compact_blank
  # Análise automática do vídeo (IA ou reconhecimento corporal). Desligada: hoje o
  # vídeo fica na fila do mentor. Só ligue depois de implementar Ai::FallAnalyzer#call.
  config.x.flipaai.automatic_review = false
end
