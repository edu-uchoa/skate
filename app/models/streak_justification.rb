# Justificativa de parada da ofensiva (lesão, chuva, provas, viagem...).
#
# Enquanto um mentor não avalia, a ofensiva fica guardada. Aprovada, a parada
# não conta; recusada, a ofensiva se perde se já tiver passado de 7 dias (Streak).
class StreakJustification < ApplicationRecord
  REASON_LENGTH = 500

  belongs_to :user
  belongs_to :reviewer, class_name: "User", optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2 }, prefix: true

  normalizes :reason, with: ->(reason) { reason.strip }

  validate do
    errors.add(:base, "Conte o motivo da parada.") if reason.blank?
    errors.add(:base, "A justificativa pode ter até #{REASON_LENGTH} letras.") if reason.to_s.length > REASON_LENGTH
  end

  # Fila do mentor: as que esperam avaliação, da mais antiga para a mais nova
  # (ninguém avalia a própria).
  scope :for_review, ->(mentor) { status_pending.where.not(user_id: mentor.id).order(:created_at) }

  def decide!(mentor, approve:)
    update!(status: approve ? :approved : :rejected, reviewer: mentor, reviewed_at: Time.current)
  end

  def created_on = created_at.in_time_zone(user.time_zone).to_date
end
