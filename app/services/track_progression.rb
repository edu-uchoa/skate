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

      if %w[completed skipped in_progress].include?(current)
        statuses[maneuver.id] = current
        next
      end

      unlocked = maneuver.prerequisite_id.nil? || ManeuverProgress::UNLOCKING.include?(statuses[maneuver.prerequisite_id])
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

  # Nó atual (a seta laranja do mapa) = primeiro disponível ou em andamento na
  # ordem da trilha. Todo mundo começa na 0.1, e a seta só anda quando a tarefa é
  # concluída pela devolutiva do mentor ou pulada pela pessoa ("Avançar").
  def current_maneuver
    Maneuver.ordered.find { |m| %w[available in_progress].include?(status_for(m)) }
  end

  def completed_count = progresses.values.count(&:status_completed?)

  def percentage
    total = Maneuver.count
    return 0 if total.zero?
    (completed_count * 100.0 / total).round
  end

  # Chamado quando um treino é enviado. Não conclui a tarefa (nem quando a pessoa
  # diz que se sentiu segura): quem conclui é a devolutiva do mentor (complete!).
  def record_attempt!(training_session)
    progress = progress_for(training_session.maneuver)
    progress.increment!(:attempts_count)
    progress.update!(status: :in_progress) if progress.status_available?

    sync!
    progress
  end

  # A devolutiva do mentor conclui a tarefa: ganha o check e a seta vai para a próxima.
  def complete!(maneuver)
    progress_for(maneuver).complete!
    sync!
  end

  # "Avançar para a próxima tarefa" sem a devolutiva do mentor: a tarefa fica pulada
  # (liberada, sem check) e destrava a próxima. Só vale para a tarefa liberada e
  # ainda não concluída. Se o mentor responder depois, ela é concluída normalmente.
  def skip!(maneuver)
    progress = progress_for(maneuver)
    return false unless progress.status_available? || progress.status_in_progress?

    progress.update!(status: :skipped)
    sync!
    true
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
