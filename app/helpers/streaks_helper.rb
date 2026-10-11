module StreaksHelper
  STATE_LABELS = {
    none: "Comece agora", active: "Ativa", frozen: "Guardada", paused: "Parada aprovada", lost: "Perdida"
  }.freeze

  def streak_state_label(streak) = STATE_LABELS.fetch(streak.state)

  # "Sáb, 18/10"
  def short_date(date) = "#{Meetup::WEEKDAYS[date.wday]}, #{date.strftime("%d/%m")}"

  # A situação da ofensiva numa frase, sem cobrança.
  def streak_summary(streak)
    case streak.state
    when :none
      "Registre sua primeira sessão: marque um rolê no mapa e grave uma tarefa no horário dele."
    when :active
      if streak.days_left.zero?
        "Hoje é o último dia para registrar a próxima sessão."
      else
        "Registre a próxima sessão até #{short_date(streak.deadline)} (#{pluralize(streak.days_left, "dia", plural: "dias")})."
      end
    when :frozen
      "Sua justificativa está com um mentor. Até ele avaliar, a ofensiva fica guardada."
    when :paused
      "Um mentor aprovou sua parada: a ofensiva continua quando você registrar a próxima sessão."
    when :lost
      "Faz #{streak.days_without_session} dias sem sessão. Tudo bem: registre um rolê para começar de novo."
    end
  end

  def streak_sessions_label(count) = pluralize(count, "sessão", plural: "sessões")
end
