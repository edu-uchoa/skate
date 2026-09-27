module ZinesHelper
  ANALYSIS_STEPS = %w[Gravado Resultado Análise Devolutiva].freeze

  # Rótulo, ícone, tom e quantos passos já foram vencidos em cada etapa
  # (o passo seguinte é o atual — ou o que falhou).
  ANALYSIS_STAGES = {
    awaiting_result: { label: "Registre o resultado para iniciar a análise", icon: "edit_note",    tone: "warn",  step: 1 },
    queued_offline:  { label: "Aguardando conexão para enviar",              icon: "cloud_off",    tone: "warn",  step: 1 },
    pending:         { label: "Na fila da análise",                          icon: "schedule",     tone: "info",  step: 2 },
    processing:      { label: "Analisando seu vídeo…",                       icon: "neurology",    tone: "info",  step: 2 },
    completed:       { label: "Devolutiva pronta",                           icon: "check_circle", tone: "ok",    step: 4 },
    failed:          { label: "Não foi possível analisar",                   icon: "error",        tone: "error", step: 2 }
  }.freeze

  def analysis_stage_for(training_session) = ANALYSIS_STAGES.fetch(training_session.analysis_stage)

  # Próximo passo do skatista para aquele vídeo: [texto, caminho].
  def zine_action_for(training_session)
    case training_session.analysis_stage
    when :awaiting_result, :queued_offline then [ "Registrar resultado", result_training_session_path(training_session) ]
    when :completed then [ "Ver devolutiva", training_session_ai_review_path(training_session) ]
    when :failed    then [ "Ver detalhes", training_session_ai_review_path(training_session) ]
    else                 [ "Acompanhar análise", training_session_ai_review_path(training_session) ]
    end
  end

  def zine_clip_details(training_session)
    duration = training_session.clip_duration
    source   = training_session.clip.blob.custom_metadata["source"]
    [
      training_session.created_at.in_time_zone(current_user.time_zone).strftime("%d/%m/%Y às %H:%M"),
      (format("%.1fs", duration).tr(".", ",") if duration),
      { "camera" => "Câmera", "upload" => "Upload" }[source]
    ].compact.join(" · ")
  end
end
