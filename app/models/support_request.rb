class SupportRequest < ApplicationRecord
  belongs_to :user
  belongs_to :maneuver, optional: true

  enum :kind, { injury: 0, stuck: 1, technical: 2 }, prefix: true
  enum :status, { open: 0, handled: 1 }, prefix: true

  validates :kind, presence: true

  scope :urgent, -> { where(kind: :injury, status: :open) }

  # Monta o link de WhatsApp com contexto pré-preenchido (tela de ajuda mínima).
  def whatsapp_url(number: Rails.configuration.x.sakte.support_whatsapp)
    text = case kind
           when "injury"    then "Oi, me machuquei treinando no Skate e preciso de ajuda."
           when "stuck"     then "Oi, travei na manobra #{maneuver&.label || '(não informada)'}."
           else                  "Oi, tive um problema técnico no Skate."
           end
    "https://wa.me/#{number}?text=#{CGI.escape(text)}"
  end
end
