class TrainingSession < ApplicationRecord
  belongs_to :user
  belongs_to :maneuver

  has_one :ai_review, dependent: :destroy
  has_one_attached :clip   # vídeo de até ~15s da análise de queda

  enum :status, {
    scheduled: 0,    # compromisso marcado
    in_progress: 1,  # checklist ok, treinando
    queued: 2,       # sem internet, aguardando envio
    submitted: 3,    # resultado enviado
    analyzed: 4      # devolutiva pronta
  }, prefix: true

  enum :period,  { morning: 0, afternoon: 1, night: 2 }, prefix: true
  enum :outcome, { felt_safe: 0, felt_afraid: 1, could_not: 2 }, prefix: true

  # Formatos aceitos: MP4/MOV (upload e iPhone) e WebM (gravação no Chrome/Android).
  CLIP_CONTENT_TYPES = %w[video/mp4 video/quicktime video/webm video/x-m4v].freeze

  validates :scheduled_on, presence: true, if: :status_scheduled?
  validate :validate_clip, if: -> { clip.attached? && attachment_changes.key?("clip") }
  validate :validate_recording, on: :recording

  scope :recent, -> { order(created_at: :desc) }
  # Treinos com vídeo: a coleção da aba Zine.
  scope :with_clip, -> { joins(:clip_attachment).with_attached_clip.includes(:maneuver, :ai_review) }

  CHECKLIST = %i[gear_checked ground_clear space_safe].freeze

  def checklist_complete?
    CHECKLIST.all? { |item| public_send(item) }
  end

  def start!
    return false unless checklist_complete?
    update!(status: :in_progress, started_at: Time.current)
  end

  # Envia o resultado. Sem conexão, fica na fila offline (tela "Aguardando conexão").
  def submit!(offline: false)
    if offline
      update!(status: :queued, queued_offline: true)
      return self
    end

    transaction do
      update!(status: :submitted, queued_offline: false, submitted_at: Time.current)
      TrackProgression.new(user).record_attempt!(self)
      create_ai_review!(status: :pending) if clip.attached? && ai_review.blank?
    end

    AnalyzeTrainingSessionJob.perform_later(self) if ai_review&.status_pending?
    self
  end

  def successful? = outcome_felt_safe?

  # Andamento do vídeo até a devolutiva:
  #   awaiting_result -> queued_offline -> pending -> processing -> completed | failed
  # A análise só começa depois que o skatista registra o resultado do treino.
  def analysis_stage
    return :queued_offline if status_queued?
    return :awaiting_result if ai_review.nil?
    ai_review.status.to_sym
  end

  def analysis_running? = %i[pending processing].include?(analysis_stage)

  def self.max_clip_seconds = Rails.configuration.x.sakte.max_clip_seconds
  def self.max_clip_bytes   = Rails.configuration.x.sakte.max_clip_bytes

  # Duração informada pelo navegador na gravação/seleção (salva no blob).
  def clip_duration = clip.attached? ? clip.blob.custom_metadata["duration_seconds"]&.to_f : nil

  private

  # Tela "Gravar": o vídeo é obrigatório e o checklist de segurança também.
  def validate_recording
    errors.add(:base, "Grave ou escolha um vídeo da manobra.") unless clip.attached?
    errors.add(:base, "Complete o checklist de segurança antes de enviar.") unless checklist_complete?
  end

  def validate_clip
    blob = clip.blob

    unless CLIP_CONTENT_TYPES.include?(blob.content_type)
      errors.add(:base, "Formato de vídeo não suportado. Envie MP4, MOV ou WebM.")
    end

    if blob.byte_size > self.class.max_clip_bytes
      errors.add(:base, "O vídeo passa de #{self.class.max_clip_bytes / 1.megabyte} MB. Grave um trecho menor.")
    end

    # Margem de 1s: a duração medida no navegador varia um pouco entre aparelhos.
    if clip_duration && clip_duration > self.class.max_clip_seconds + 1
      errors.add(:base, "O vídeo passa de #{self.class.max_clip_seconds} segundos. Corte ou grave de novo.")
    end
  end
end
