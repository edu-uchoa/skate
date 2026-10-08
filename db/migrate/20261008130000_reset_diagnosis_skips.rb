class ResetDiagnosisSkips < ActiveRecord::Migration[8.1]
  # O diagnóstico deixou de pular tarefas: a seta da trilha começa na 0.1 para todo
  # mundo e só anda com a devolutiva do mentor ou com "Avançar para a próxima tarefa".
  # Os "pulados" (4) que existem até aqui vieram todos do diagnóstico; voltam a
  # bloqueados (0) e a trilha se recalcula na próxima visita (TrackProgression#sync!).
  def up
    execute "UPDATE maneuver_progresses SET status = 0 WHERE status = 4"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
