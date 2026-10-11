module TasksHelper
  # Ícone, rótulo e classe de uma tarefa que ainda não foi concluída.
  def task_situation(maneuver, current)
    return [ "play_arrow", "Agora", "is-current" ] if maneuver == current

    case progression.status_for(maneuver)
    when "in_progress" then [ "pending", "Em andamento", "is-open" ]
    when "skipped"     then [ "lock_open", "Pulada", "is-open" ]
    when "available"   then [ "lock_open", "Liberada", "is-open" ]
    else                    [ "lock", "Bloqueada", "is-locked" ]
    end
  end

  # "Concluída em 12/10 · +50 XP"
  def task_done_details(maneuver)
    completed_at = progression.progresses[maneuver.id]&.completed_at
    [ ("Concluída em #{completed_at.in_time_zone(current_user.time_zone).strftime("%d/%m")}" if completed_at),
      "+#{ProfileStats.xp_for(maneuver)} XP" ].compact.join(" · ")
  end
end
