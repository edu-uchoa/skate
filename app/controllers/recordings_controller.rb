# Tela "Gravar": grava pela câmera ou envia um vídeo da manobra.
#
# O vídeo vira o `clip` de um novo TrainingSession (Active Storage guarda o
# arquivo no serviço configurado em config/storage.yml), na fila do mentor que o
# skatista escolheu. Em seguida ele registra o resultado do treino.
class RecordingsController < ApplicationController
  include MentorChoice

  before_action :redirect_mentor_account
  before_action :require_age_gate
  before_action :require_diagnosis
  before_action :set_maneuvers

  def new
    @maneuver = selected_maneuver(params[:maneuver_slug])
    # No horário de um rolê marcado no mapa, o vídeo vale para a ofensiva.
    @meetup_now = current_user.meetups.provable_at(Time.current).order(:starts_at).first
    load_mentor_choice
  end

  def create
    load_mentor_choice(params.dig(:recording, :mentor_id))
    @maneuver = selected_maneuver(params.dig(:recording, :maneuver_slug))
    @training_session = build_training_session

    if @training_session.save(context: :recording)
      respond_to do |format|
        # Pela tela de envio (anel de progresso): ela mesma mostra o "enviado com sucesso".
        format.json { render json: { redirect_url: result_training_session_path(@training_session) }, status: :created }
        format.html do
          redirect_to result_training_session_path(@training_session),
                      notice: "Vídeo salvo e já na fila do mentor. Conte como foi o treino."
        end
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @training_session.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # Tela de envio dos vídeos que ficaram guardados neste aparelho (sem internet na hora).
  # A lista fica só no celular (lib/upload_queue.js): o servidor não sabe de nada até chegar.
  def sending; end

  private

  def recording_params
    params.fetch(:recording, {}).permit(:clip, :duration_seconds, :cut_from, :cut_to, :source, :mentor_id, *TrainingSession::CHECKLIST)
  end

  def build_training_session
    attrs = recording_params
    session = current_user.training_sessions.build(
      maneuver: @maneuver, scheduled_on: Date.current,
      status: :in_progress, started_at: Time.current,
      # Só um mentor da lista; outro valor (ou mentor que saiu) = qualquer mentor responde.
      mentor: User.available_mentor(attrs[:mentor_id]),
      **TrainingSession::CHECKLIST.index_with { |item| attrs[item] == "1" }
    )

    if attrs[:clip].respond_to?(:original_filename)
      # Só o trecho da barra de corte (até 20s) é guardado, limpo e sem localização (ClipSanitizer).
      cut = TrainingSession.clip_cut(attrs[:cut_from], attrs[:cut_to], attrs[:duration_seconds])
      session.clip_cut = cut
      session.clip.attach(attrs[:clip])
      session.clip.blob.custom_metadata = clip_metadata(attrs, cut) if session.clip.attached?
    end

    session
  end

  # duration_seconds: quanto dura o que foi guardado (o trecho), quando o navegador
  # informou a duração do vídeo. cut_from_seconds: onde o trecho começava no original.
  def clip_metadata(attrs, cut)
    duration = attrs[:duration_seconds].to_f
    {
      "duration_seconds" => ((cut.end - cut.begin).round(2) if duration.positive? && duration.finite?),
      "cut_from_seconds" => (cut.begin if cut.begin.positive?),
      "source"           => attrs[:source].presence_in(%w[camera upload]) || "upload"
    }.compact
  end

  # Só manobras já liberadas na trilha podem receber vídeo.
  def set_maneuvers
    progression.sync!
    @maneuvers = Maneuver.ordered.reject { |m| progression.status_for(m) == "locked" }
  end

  def selected_maneuver(slug)
    @maneuvers.find { |m| m.slug == slug } || progression.current_maneuver || @maneuvers.first
  end
end
