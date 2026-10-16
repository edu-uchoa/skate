class AiReview < ApplicationRecord
  belongs_to :training_session
  belongs_to :reviewer, class_name: "User", optional: true # mentor que respondeu
  has_one :user, through: :training_session

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }, prefix: true

  TEXT_LENGTH = 600

  def finished? = status_completed? || status_failed?

  def awaiting_mentor? = status_pending? || status_processing?

  # Devolutiva escrita pelo mentor: o aprendiz vê na tela que já existe
  # (ai_reviews/_review). Devolve false com os erros em português.
  def answer(mentor, **texts)
    return false unless assign_texts(**texts)

    transaction do
      update!(status: :completed, reviewer: mentor, completed_at: Time.current, raw_response: "mentor")
      training_session.update!(status: :analyzed)
      # A devolutiva conclui a tarefa do aprendiz e a seta da trilha avança.
      TrackProgression.new(training_session.user).complete!(training_session.maneuver)
      # Se o vídeo comprovou um rolê, a sessão da ofensiva fica validada.
      training_session.skate_session&.update!(validated_at: Time.current)
    end
    true
  end

  # O mentor revisa uma devolutiva já enviada (aba "Todos"): o aprendiz passa a ver
  # o texto novo. A tarefa continua concluída.
  def revise(**texts)
    return false unless status_completed? && assign_texts(**texts)

    update!(revised_at: Time.current)
  end

  # Super administrador apagou a devolutiva (o comentário do mentor no vídeo): o texto
  # some para o aprendiz e o vídeo volta para a fila do mentor. A tarefa que a
  # devolutiva concluiu continua concluída.
  def retract!
    transaction do
      update!(status: :pending, headline: nil, strengths: nil, mistake: nil, next_focus: nil,
              raw_response: nil, reviewer: nil, completed_at: nil, revised_at: nil)
      training_session.update!(status: :submitted) if training_session.status_analyzed?
    end
  end

  def apply!(result)
    update!(
      status: :completed,
      headline: result[:headline],
      strengths: result[:strengths],
      mistake: result[:mistake],
      next_focus: result[:next_focus],
      raw_response: result[:raw].to_s,
      completed_at: Time.current
    )
    training_session.update!(status: :analyzed)
  end

  def fail!(message)
    update!(status: :failed, error_message: message.to_s.truncate(255))
  end

  private

  # As três partes são obrigatórias; a frase de destaque, não.
  def assign_texts(headline:, strengths:, mistake:, next_focus:)
    self.headline   = headline.to_s.strip.first(TEXT_LENGTH).presence || "Devolutiva do seu #{training_session.maneuver.name.downcase}"
    self.strengths  = strengths.to_s.strip.first(TEXT_LENGTH)
    self.mistake    = mistake.to_s.strip.first(TEXT_LENGTH)
    self.next_focus = next_focus.to_s.strip.first(TEXT_LENGTH)

    { strengths: "o que o aprendiz fez bem", mistake: "onde foi o erro", next_focus: "o foco da próxima sessão" }.each do |field, label|
      errors.add(:base, "Escreva #{label}.") if public_send(field).blank?
    end
    errors.none?
  end
end
