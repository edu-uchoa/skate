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

  # O prazo conta desde que o vídeo chegou (TrainingSession#waiting_since).
  def overdue?(training_session) = training_session.waiting_since < RESPONSE_HOURS.hours.ago

  def waiting_label(training_session)
    hours = ((Time.current - training_session.waiting_since) / 1.hour).floor
    if hours < 1 then "Chegou agora"
    elsif hours < RESPONSE_HOURS then "Esperando há #{hours}h"
    else "Esperando há #{hours / 24} dias · passou do prazo de #{RESPONSE_HOURS}h"
    end
  end

  # "Devolutiva enviada em 12/10 às 14:30 · revisada em 13/10"
  def review_sent_label(ai_review)
    zone = current_user.time_zone
    sent_at = ai_review.completed_at || ai_review.updated_at # devolutivas antigas não guardavam a hora do envio
    [ "Devolutiva enviada em #{sent_at.in_time_zone(zone).strftime("%d/%m às %H:%M")}",
      ("revisada em #{ai_review.revised_at.in_time_zone(zone).strftime("%d/%m")}" if ai_review.revised_at) ].compact.join(" · ")
  end
end
