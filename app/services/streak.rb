# Ofensiva por sessão de skate (não é diária).
#
# Cada sessão registrada (SkateSession) soma 1, no máximo uma por dia. Sessão
# registrada = rolê marcado no mapa de Picos + vídeo de uma tarefa gravado no
# horário do rolê + resultado enviado; a devolutiva do mentor valida.
#
# A ofensiva só se perde quando a pessoa passa mais de 7 dias sem sessão. Uma
# justificativa de parada (StreakJustification) segura a ofensiva enquanto um
# mentor avalia; aprovada, aquela parada não conta; recusada, conta.
class Streak
  GAP_DAYS = 7

  # :none (sem sessão ainda), :active, :frozen (justificativa esperando o mentor),
  # :paused (parada aprovada pelo mentor) ou :lost.
  STATES = %i[none active frozen paused lost].freeze

  attr_reader :today

  def initialize(user)
    @user  = user
    @today = Time.current.in_time_zone(user.time_zone).to_date
  end

  def count = alive? ? current_chain.size : 0
  def best = chains.map(&:size).max || 0
  def last_session_on = days.last

  # Até quando dá para registrar a próxima sessão sem perder a ofensiva.
  def deadline = last_session_on && last_session_on + GAP_DAYS
  def days_left = deadline && (deadline - today).to_i
  def days_without_session = last_session_on && (today - last_session_on).to_i

  def state
    return :none if days.empty?
    return :active if days_without_session <= GAP_DAYS

    case current_justification&.status
    when "pending"  then :frozen
    when "approved" then :paused
    else :lost
    end
  end

  def alive? = state.in?(%i[active frozen paused])

  # A justificativa da parada atual (feita depois da última sessão), se houver.
  def current_justification
    return unless last_session_on

    justifications.select { |justification| justification.created_on >= last_session_on }.max_by(&:created_at)
  end

  # Uma justificativa por parada, e só para quem já tem sessão.
  def can_justify? = days.any? && current_justification.nil?

  def sessions = user.skate_sessions.recent

  private

  attr_reader :user

  # Consultas novas (não o que já estiver carregado em user): a decisão do mentor
  # vale na hora, e um formulário em branco não entra na conta.
  def days = @days ||= SkateSession.where(user_id: user.id).distinct.order(:skated_on).pluck(:skated_on)
  def justifications = @justifications ||= StreakJustification.where(user_id: user.id).to_a

  # Sequências de sessões em que cada intervalo é de até 7 dias, ou em que a
  # parada foi justificada (esperando o mentor ou aprovada) enquanto acontecia.
  def chains
    @chains ||= days.slice_when { |previous, day| (day - previous).to_i > GAP_DAYS && !justified?(previous, day) }.to_a
  end

  def current_chain = chains.last || []

  def justified?(from, to)
    justifications.any? { |justification| !justification.status_rejected? && justification.created_on.between?(from, to) }
  end
end
