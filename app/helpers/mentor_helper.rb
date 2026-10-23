module MentorHelper
  RESPONSE_HOURS = TrainingSession::REVIEW_HOURS # prazo prometido ao aprendiz na tela de espera

  LEVEL_LABELS = {
    "never_ridden"   => "Começando do zero",
    "can_push"       => "Já rema e faz curvas",
    "stuck_on_ollie" => "Travado no ollie",
    "advanced"       => "Já manda ollie"
  }.freeze

  # As 3 perguntas do cadastro e as respostas, com os mesmos textos das telas do
  # diagnóstico (onboarding/diagnoses), para o mentor ver no Perfil do aprendiz.
  DIAGNOSIS_QUESTIONS = {
    level:    "Qual é o seu nível hoje?",
    blockers: "O que é mais difícil hoje?",
    setup:    "Como é o seu skate hoje?"
  }.freeze

  DIAGNOSIS_ANSWERS = {
    level: { "never_ridden" => "Nunca subi em um skate", "can_push" => "Consigo remar e fazer curvas",
             "stuck_on_ollie" => "Estou travado tentando o Ollie", "advanced" => "Já mando Ollie com firmeza" },
    blockers: { "fear_of_falling" => "Medo de cair e me machucar", "shame" => "Vergonha de treinar na frente dos outros",
                "foot_technique" => "Não sei qual o movimento certo do pé", "no_place" => "Falta de lugar adequado e vazio" },
    setup: { "no_board" => "Não tenho skate ainda", "store_board" => "Skate montado comum",
             "skateshop_board" => "Skate de skateshop profissional", "other_board" => "Outro tipo de prancha" }
  }.freeze

  # [[pergunta, [respostas]], ...]; vazio se o aprendiz ainda não respondeu.
  def diagnosis_answers(diagnosis)
    return [] if diagnosis.nil?

    answers = {
      level:    [ diagnosis.level ],
      blockers: diagnosis.diagnosis_blockers.map(&:kind),
      setup:    [ diagnosis.setup ]
    }
    DIAGNOSIS_QUESTIONS.map { |step, question| [ question, answers[step].filter_map { DIAGNOSIS_ANSWERS[step][it] } ] }
  end

  OUTCOME_LABELS = {
    "felt_safe"   => "Se sentiu seguro",
    "felt_afraid" => "Fez com medo",
    "could_not"   => "Não saiu / travou"
  }.freeze

  # O mentor identifica o aprendiz sem ver o contato (muitos são menores): pelo
  # nickname#0000, ou, nas contas que ainda não escolheram, pelo contato mascarado.
  def masked_contact(user)
    if user.handle
      user.handle
    elsif user.email.present?
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
  def overdue?(training_session) = training_session.review_overdue?

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
