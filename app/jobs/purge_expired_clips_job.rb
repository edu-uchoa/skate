# Apaga os vídeos que passaram de 1 mês (TrainingSession::CLIP_RETENTION). Roda a
# cada 10 minutos em produção (config/recurring.yml); as telas com vídeo também
# limpam ao abrir, para ninguém ver um vídeo vencido.
class PurgeExpiredClipsJob < ApplicationJob
  def perform = TrainingSession.purge_expired_clips!
end
