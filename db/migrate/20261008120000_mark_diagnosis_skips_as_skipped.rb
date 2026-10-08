class MarkDiagnosisSkipsAsSkipped < ActiveRecord::Migration[8.1]
  # Os nós que o diagnóstico pulava eram gravados como concluídos (3), e o mapa da
  # trilha mostrava check em manobras nunca treinadas. Passam a "pulados" (4).
  # Concluído de verdade sempre tem tentativa (TrackProgression#record_attempt!).
  def up
    execute "UPDATE maneuver_progresses SET status = 4, completed_at = NULL WHERE status = 3 AND attempts_count = 0"
  end

  def down
    execute "UPDATE maneuver_progresses SET status = 3, completed_at = updated_at WHERE status = 4"
  end
end
