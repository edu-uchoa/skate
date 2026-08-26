# Regras de desbloqueio da trilha.
#
# Um nó fica disponível quando não tem pré-requisito ou quando o pré-requisito
# foi concluído. É o que alimenta a tela "Mapa da Trilha".
class TrackProgression
  def initialize(user)
    @user = user
  end

  # Cria/atualiza o progresso de todos os nós. Idempotente.
  #
  # A trilha é percorrida em ordem (Maneuver.ordered), então o pré-requisito de
  # um nó sempre é avaliado antes dele — por isso dá para resolver tudo em uma
  # passada, sem recursão.
  def sync!
    statuses = progresses.transform_values(&:status)

    Maneuver.ordered.includes(:prerequisite).each do |maneuver|
      progress = progress_for(maneuver)
      current  = statuses[maneuver.id] || progress.status

      if %w[completed in_progress].include?(current)
        statuses[maneuver.id] = current
        next
      end

      unlocked = maneuver.prerequisite_id.nil? || statuses[maneuver.prerequisite_id] == "completed"
      status   = unlocked ? "available" : "locked"

      progress.update!(status: status) unless progress.status == status
      statuses[maneuver.id] = status
    end

    reload!
  end

  def progresses
    @progresses ||= user.maneuver_progresses.includes(maneuver: :learning_module).index_by(&:maneuver_id)
  end

  def status_for(maneuver)
    progresses[maneuver.id]&.status || "locked"
  end

  # Nó atual = primeiro disponível ou em andamento na ordem da trilha.
  def current_maneuver
    Maneuver.ordered.find { |m| %w[available in_progress].include?(status_for(m)) }
  end

  def completed_count = progresses.values.count(&:status_completed?)

  def percentage
    total = Maneuver.count
    return 0 if total.zero?
    (completed_count * 100.0 / total).round
  end

  # Chamado quando um treino é enviado.
  def record_attempt!(training_session)
    progress = progress_for(training_session.maneuver)
    progress.increment!(:attempts_count)

    if training_session.successful?
      progress.complete!
    elsif progress.status_available?
      progress.update!(status: :in_progress)
    end

    sync!
    progress
  end

  # Marca como concluídos os nós anteriores ao ponto de entrada do diagnóstico.
  def start_at!(maneuver)
    Maneuver.ordered.each do |m|
      break if m.id == maneuver.id
      progress_for(m).update!(status: :completed, completed_at: Time.current)
    end
    progress_for(maneuver).update!(status: :available)
    sync!
  end

  private

  attr_reader :user

  def reload!
    @progresses = nil
    user.maneuver_progresses.reset
    self
  end

  def progress_for(maneuver)
    progresses[maneuver.id] ||= user.maneuver_progresses.find_or_create_by!(maneuver: maneuver)
  end
end
