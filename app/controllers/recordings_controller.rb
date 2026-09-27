# Tela "Gravar": grava pela câmera ou envia um vídeo da manobra.
#
# O vídeo vira o `clip` de um novo TrainingSession (Active Storage guarda o
# arquivo no serviço configurado em config/storage.yml). Em seguida o skatista
# registra o resultado e o envio dispara a análise da IA (AiReview).
class RecordingsController < ApplicationController
  before_action :require_age_gate
  before_action :require_diagnosis
  before_action :set_maneuvers

  def new
    @maneuver = selected_maneuver(params[:maneuver_slug])
  end

  def create
    @maneuver = selected_maneuver(params.dig(:recording, :maneuver_slug))
    @training_session = build_training_session

    if @training_session.save(context: :recording)
      flash[:notice] = "Vídeo salvo na sua Zine. Registre o resultado para a IA analisar."
      respond_to do |format|
        format.json { render json: { redirect_url: result_training_session_path(@training_session) }, status: :created }
        format.html { redirect_to result_training_session_path(@training_session) }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @training_session.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def recording_params
    params.fetch(:recording, {}).permit(:clip, :duration_seconds, :source, *TrainingSession::CHECKLIST)
  end

  def build_training_session
    attrs = recording_params
    session = current_user.training_sessions.build(
      maneuver: @maneuver, scheduled_on: Date.current,
      status: :in_progress, started_at: Time.current,
      **TrainingSession::CHECKLIST.index_with { |item| attrs[item] == "1" }
    )

    if attrs[:clip].respond_to?(:original_filename)
      session.clip.attach(attrs[:clip])
      session.clip.blob.custom_metadata = clip_metadata(attrs)
    end

    session
  end

  def clip_metadata(attrs)
    duration = attrs[:duration_seconds].to_f
    {
      "duration_seconds" => (duration.positive? && duration.finite? ? duration.round(2) : nil),
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
