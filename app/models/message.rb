# Mensagem do chat entre aprendiz e mentores (Conversation).
class Message < ApplicationRecord
  BODY_LENGTH = 1000

  # Contato de fora do app não entra no chat: há aprendizes menores de idade.
  CONTACT_PATTERNS = [
    /[\w.+-]+@[\w-]+\.[a-z]{2,}/i,                                  # e-mail
    %r{https?://|www\.|\b[\w-]+\.(com|net|org|br|me|app|io|gg|ly|tv)\b}i, # link
    /(?:\d[\s().-]*){8,}/,                                          # telefone (8 dígitos ou mais)
    /(?:^|\s)@[\w.]{3,}/                                            # @ de rede social
  ].freeze

  belongs_to :conversation, inverse_of: :messages
  belongs_to :author, class_name: "User", optional: true # some se a conta do mentor for apagada

  normalizes :body, with: ->(body) { body.to_s.strip }

  validate :readable_body

  def from_learner? = author_id.present? && author_id == conversation.learner_id

  private

  def readable_body
    if body.blank?
      errors.add(:base, "Escreva a mensagem.")
    elsif body.length > BODY_LENGTH
      errors.add(:base, "A mensagem passa de #{BODY_LENGTH} caracteres. Divida em duas.")
    elsif CONTACT_PATTERNS.any? { |pattern| body.match?(pattern) }
      errors.add(:base, "Por segurança, não mande telefone, e-mail, links ou @ de redes sociais no chat.")
    end
  end
end
