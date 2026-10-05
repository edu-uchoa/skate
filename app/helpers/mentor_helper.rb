module MentorHelper
  RESPONSE_HOURS = 48 # prazo prometido ao aprendiz na tela de espera

  LEVEL_LABELS = {
    "never_ridden"   => "Começando do zero",
    "can_push"       => "Já rema e faz curvas",
    "stuck_on_ollie" => "Travado no ollie",
    "advanced"       => "Já manda ollie"
  }.freeze

  OUTCOME_LABELS = {
    "felt_safe"   => "Se sentiu seguro",
    "felt_afraid" => "Fez com medo",
    "could_not"   => "Não saiu / travou"
  }.freeze

  # O mentor identifica o aprendiz sem ver o contato inteiro (muitos são menores).
  def masked_contact(user)
    if user.email.present?
      name, domain = user.email.split("@", 2)
      "#{name.first(2)}•••@#{domain}"
    elsif user.phone.present?
      "(#{user.phone.first(2)}) •••••-#{user.phone.last(4)}"
    else
      "Aprendiz ##{user.id}"
    end
  end

  def learner_summary(user)
    [ ("#{user.age} anos" if user.age), LEVEL_LABELS[user.diagnosis&.level] ].compact.join(" · ")
  end

  def outcome_label(training_session) = OUTCOME_LABELS[training_session.outcome]

  def overdue?(ai_review) = ai_review.created_at < RESPONSE_HOURS.hours.ago

  def waiting_label(ai_review)
    hours = ((Time.current - ai_review.created_at) / 1.hour).floor
    if hours < 1 then "Chegou agora"
    elsif hours < RESPONSE_HOURS then "Esperando há #{hours}h"
    else "Esperando há #{hours / 24} dias · passou do prazo de #{RESPONSE_HOURS}h"
    end
  end
end
