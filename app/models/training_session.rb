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

  validates :scheduled_on, presence: true, if: :status_scheduled?

  scope :recent, -> { order(created_at: :desc) }

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
end
