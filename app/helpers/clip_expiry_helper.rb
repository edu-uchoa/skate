# Aviso do prazo dos vídeos: cada vídeo é apagado exatamente 1 mês depois do envio
# (TrainingSession::CLIP_RETENTION).
module ClipExpiryHelper
  # "Será apagado em 29 dias, em 18/11/2026 às 10:49" (no fuso da pessoa que está vendo).
  def clip_expiry_label(training_session)
    expires_at = training_session.clip_expires_at.in_time_zone(current_user.time_zone)
    "Será apagado #{time_left_until(expires_at)}, em #{expires_at.strftime("%d/%m/%Y às %H:%M")}"
  end

  # Falta pouco (menos de 3 dias): o aviso fica em destaque.
  def clip_expiring_soon?(training_session) = training_session.clip_expires_at < 3.days.from_now

  private

  def time_left_until(time)
    seconds = (time - Time.current).to_f
    minutes = [ (seconds / 1.minute).round, 1 ].max

    # Arredonda para o mais próximo: 1 dia e 23 horas é "em 2 dias".
    if seconds >= 1.day then "em #{pluralize((seconds / 1.day).round, "dia", plural: "dias")}"
    elsif seconds >= 1.hour then "em #{pluralize((seconds / 1.hour).round, "hora", plural: "horas")}"
    else "em #{pluralize(minutes, "minuto", plural: "minutos")}"
    end
  end
end
