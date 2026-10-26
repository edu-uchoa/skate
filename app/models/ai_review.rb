class AiReview < ApplicationRecord
  belongs_to :training_session
  belongs_to :reviewer, class_name: "User", optional: true # mentor que respondeu
  has_one :user, through: :training_session

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }, prefix: true

  TEXT_LENGTH = 600

  # Avaliação que o aprendiz dá ao mentor na devolutiva: de 1 a 10 rolamentos e uma
  # mensagem opcional. Entra na média do mentor (MentorRating).
  RATINGS = 1..10
  RATING_COMMENT_LENGTH = 500

  scope :rated, -> { where.not(rating: nil) }

  # Devolutivas que o aprendiz ainda não abriu (ou que o mentor revisou depois que ele
  # abriu): viram o número no ícone Zine e a marca "Nova" no cartão do vídeo.
  scope :unseen, -> { status_completed.where("ai_reviews.seen_at IS NULL OR ai_reviews.revised_at > ai_reviews.seen_at") }

  def finished? = status_completed? || status_failed?

  def unseen? = status_completed? && (seen_at.nil? || (revised_at.present? && revised_at > seen_at))

  # "Nova" (nunca aberta) ou "Atualizada" (o mentor revisou depois que o aprendiz abriu).
  def unseen_label = seen_at ? "Atualizada" : "Nova"

  # O aprendiz abriu a devolutiva: o aviso some.
  def mark_seen!
    update_column(:seen_at, Time.current) if unseen?
  end

  def awaiting_mentor? = status_pending? || status_processing?

  # Devolutiva escrita por um mentor, que o aprendiz ainda pode avaliar (uma vez só).
  def rateable? = status_completed? && reviewer_id.present? && rating.nil?

  # A devolutiva é de quem escreveu: o aprendiz a vê com o nome e a média desse mentor.
  # Só ele revisa o texto; outro mentor ou a administração, não (o super admin pode
  # apagá-la pelo painel).
  def revisable_by?(mentor) = status_completed? && reviewer_id.present? && reviewer_id == mentor&.id

  # O aprendiz avalia a devolutiva. Devolve false com os erros em português.
  def rate(rating, comment = nil)
    rating = Integer(rating, exception: false)
    comment = comment.to_s.strip.presence
    errors.clear

    if self.rating
      errors.add(:base, "Essa devolutiva já foi avaliada.")
    elsif !rateable?
      errors.add(:base, "Só dá para avaliar a devolutiva escrita por um mentor.")
    elsif !RATINGS.cover?(rating)
      errors.add(:base, "Escolha de 1 a 10 rolamentos.")
    elsif comment && comment.length > RATING_COMMENT_LENGTH
      errors.add(:base, "A mensagem passa de #{RATING_COMMENT_LENGTH} caracteres. Deixe mais curta.")
    elsif comment && Message::CONTACT_PATTERNS.any? { |pattern| comment.match?(pattern) }
      errors.add(:base, "Por segurança, não mande telefone, e-mail, links ou @ de redes sociais.")
    end
    return false if errors.any?

    update!(rating: rating, rating_comment: comment, rated_at: Time.current)
  end

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
  # devolutiva concluiu continua concluída. A avaliação dada a ela sai da média.
  def retract!
    transaction do
      update!(status: :pending, headline: nil, strengths: nil, mistake: nil, next_focus: nil,
              raw_response: nil, reviewer: nil, completed_at: nil, revised_at: nil, seen_at: nil,
              rating: nil, rating_comment: nil, rated_at: nil)
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
