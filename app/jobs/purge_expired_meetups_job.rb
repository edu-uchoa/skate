# Apaga os rolês que já acabaram (roda de hora em hora em produção, config/recurring.yml).
# A página de Picos também limpa ao abrir. Não guardamos onde ninguém andou.
class PurgeExpiredMeetupsJob < ApplicationJob
  def perform = Meetup.purge_expired!
end
