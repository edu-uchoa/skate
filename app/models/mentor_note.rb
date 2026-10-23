# Observação da equipe de mentores sobre um aprendiz: o que treinar na próxima aula, o
# que ajuda ele a evoluir. No app só os mentores veem (Perfil do aprendiz, na área do
# mentor); pela LGPD ela vai na cópia de dados que o aprendiz pode baixar (DataExport).
class MentorNote < ApplicationRecord
  BODY_LENGTH = 1000

  belongs_to :learner, class_name: "User", inverse_of: :mentor_notes
  belongs_to :author, class_name: "User", optional: true, inverse_of: :written_mentor_notes # some se a conta do mentor for apagada

  normalizes :body, with: ->(body) { body.to_s.strip }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  validate :readable_body

  # Apagar: quem escreveu ou a administração.
  def deletable_by?(user) = author_id == user.id || user.admin_access?

  private

  def readable_body
    if body.blank?
      errors.add(:base, "Escreva a observação.")
    elsif body.length > BODY_LENGTH
      errors.add(:base, "A observação passa de #{BODY_LENGTH} caracteres. Divida em duas.")
    elsif Message::CONTACT_PATTERNS.any? { |pattern| body.match?(pattern) }
      errors.add(:base, "Por segurança, não escreva telefone, e-mail, links ou @ de redes sociais.")
    end
  end
end
