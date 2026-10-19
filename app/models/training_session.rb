class TrainingSession < ApplicationRecord
  belongs_to :user
  belongs_to :maneuver

  has_one :ai_review, dependent: :destroy
  has_many :clip_accesses, dependent: :delete_all # quem (além do dono) assistiu ao vídeo
  has_one :skate_session, dependent: :nullify      # se este vídeo comprovou um rolê (ofensiva)
  has_one_attached :clip   # vídeo do treino; guardado em 720p (TranscodeClipJob)

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

  CLIP_PROBLEMS = {
    format:      "Formato de vídeo não suportado. Envie MP4, MOV ou WebM.",
    size:        "O vídeo passa de %{mb} MB, o máximo que dá para receber. Corte um trecho e envie de novo.",
    unreadable:  "Não conseguimos ler este vídeo. Grave de novo ou escolha outro arquivo.",
    unavailable: "Não conseguimos proteger este vídeo agora. Tente de novo em alguns minutos."
  }.freeze

  validates :scheduled_on, presence: true, if: :status_scheduled?
  validate :validate_clip, if: -> { clip.attached? && attachment_changes.key?("clip") }
  # Vídeo gravado no horário de um rolê marcado no mapa: vale como sessão da ofensiva.
  before_save -> { self.recorded_at_meetup = user.meetups.provable_at(Time.current).exists? },
              if: -> { attachment_changes.key?("clip") && clip.attached? && !@replacing_clip }
  # Vídeo novo: recomprime para 720p em segundo plano, sem o envio esperar.
  after_commit :schedule_transcode, if: -> { @clip_uploaded }
  validate -> { errors.add(:base, clip_problem(@clip_problem)) }, if: -> { @clip_problem }
  validate :validate_recording, on: :recording

  scope :recent, -> { order(created_at: :desc) }
  # Treinos com vídeo: a coleção da aba Zine.
  scope :with_clip, -> { joins(:clip_attachment).with_attached_clip.includes(:maneuver, :ai_review) }
  # Vídeos de aprendizes (os de mentores e administradores ficam fora da área do mentor).
  scope :of_learners, -> { with_clip.joins(:user).merge(User.role_learner) }
  # Vídeos que ainda esperam a devolutiva de um mentor ("Na fila" da Zine do mentor).
  # Entram assim que o vídeo chega: o resultado que o aprendiz registra é só um dado a mais.
  scope :awaiting_review, -> { where.not(id: AiReview.status_completed.select(:training_session_id)) }

  # Cada vídeo fica guardado por 1 mês, contado de quando a pessoa enviou; depois é
  # apagado sozinho (PurgeExpiredClipsJob). A devolutiva já recebida continua.
  CLIP_RETENTION = 1.month
  scope :clip_expired, -> { joins(:clip_attachment).where(clip_uploaded_at: ..CLIP_RETENTION.ago) }

  # Apaga os vídeos que passaram do prazo. Devolve quantos apagou.
  def self.purge_expired_clips!
    clip_expired.find_each.count do |training_session|
      training_session.remove_clip!
      Rails.logger.info("[FlipaAi] vídeo do treino #{training_session.id} apagado: passou de 1 mês")
    end
  end

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
      # Se o mentor já respondeu ao vídeo, o treino continua com a devolutiva pronta.
      update!(status: (status_analyzed? ? :analyzed : :submitted), queued_offline: false, submitted_at: Time.current)
      TrackProgression.new(user).record_attempt!(self)
      create_ai_review!(status: :pending) if clip.attached? && ai_review.blank?
      register_skate_session
    end

    # Sem análise automática, o vídeo fica pendente na fila do mentor.
    AnalyzeTrainingSessionJob.perform_later(self) if ai_review&.status_pending? && self.class.automatic_review?
    self
  end

  # Todo vídeo é limpo pelo ClipSanitizer antes de ser guardado: o original, com
  # a localização de onde foi gravado, nunca chega ao armazenamento. Vale para
  # clip=, clip.attach e os formulários. Se não der para limpar, o vídeo não entra.
  def clip=(attachable)
    @clip_problem = nil
    return super if attachable.nil? || attachable == ""

    super(ClipSanitizer.new(attachable, max_bytes: self.class.max_clip_bytes).call)
    return if @replacing_clip

    @clip_uploaded = true
    self.clip_uploaded_at = Time.current # o prazo de 1 mês conta daqui
  rescue ClipSanitizer::Error => e
    @clip_problem = e.reason
  end

  # Quem pode assistir ao vídeo: o dono; se o dono é aprendiz, mentores e
  # administradores; e o super administrador, qualquer vídeo (para moderar).
  def clip_visible_to?(viewer)
    return false if viewer.nil?
    user_id == viewer.id || viewer.super_admin? || (viewer.mentor_access? && user.role_learner?)
  end

  # Quem pode apagar o vídeo: o dono e a administração (mentor não apaga).
  def clip_deletable_by?(viewer)
    clip_visible_to?(viewer) && (user_id == viewer.id || viewer.admin_access?)
  end

  # Apaga o vídeo. O progresso na trilha e uma devolutiva já recebida continuam; a
  # devolutiva ainda não escrita sai, e o rolê ainda não validado pelo mentor deixa de
  # valer para a ofensiva.
  def remove_clip!
    transaction do
      ai_review.destroy! if ai_review&.awaiting_mentor?
      skate_session.destroy! if skate_session && !skate_session.validated?
      clip.purge
    end
  end

  # Troca o arquivo pela versão recomprimida (TranscodeClipJob) sem contar como envio
  # novo: o rolê da ofensiva e a fila do mentor continuam os mesmos.
  def replace_clip_with(io, metadata:)
    @replacing_clip = true
    clip.attach(io: io, filename: "video.mp4", content_type: "video/mp4")
    return false unless clip.attached?

    clip.blob.custom_metadata = metadata
    clip.blob.save!
  ensure
    @replacing_clip = false
  end

  # Andamento do vídeo até a devolutiva:
  #   awaiting_result -> queued_offline -> pending -> processing -> completed | failed
  # A análise só começa depois que o skatista registra o resultado do treino.
  def analysis_stage
    return :queued_offline if status_queued?
    return :awaiting_result if ai_review.nil?
    ai_review.status.to_sym
  end

  def analysis_running? = %i[pending processing].include?(analysis_stage)

  # Ainda sem a devolutiva do mentor (tem vídeo e nenhuma resposta pronta).
  def awaiting_review? = clip.attached? && !ai_review&.status_completed?

  # Desde quando o vídeo espera o mentor (o prazo de 48h conta a partir daqui).
  def waiting_since = clip_uploaded_at || clip.blob.created_at

  # Quando o vídeo será apagado (exatamente 1 mês depois do envio).
  def clip_expires_at = waiting_since + CLIP_RETENTION

  def clip_expired? = clip_expires_at <= Time.current

  def self.max_clip_seconds = Rails.configuration.x.flipaai.max_clip_seconds
  def self.max_clip_bytes   = Rails.configuration.x.flipaai.max_clip_bytes
  def self.automatic_review? = Rails.configuration.x.flipaai.automatic_review

  # Duração informada pelo navegador na gravação/seleção (salva no blob).
  def clip_duration = clip.attached? ? clip.blob.custom_metadata["duration_seconds"]&.to_f : nil

  private

  def clip_problem(reason) = format(CLIP_PROBLEMS.fetch(reason), mb: self.class.max_clip_bytes / 1.megabyte)

  # Vídeo do rolê + resultado enviado = sessão da ofensiva, no dia em que o vídeo
  # foi gravado. A devolutiva do mentor valida (AiReview#answer).
  def register_skate_session
    return unless clip.attached? && recorded_at_meetup? && skate_session.nil?

    # Se o mentor já respondeu, a sessão já nasce validada.
    create_skate_session!(user: user, skated_on: waiting_since.in_time_zone(user.time_zone).to_date,
                          validated_at: (Time.current if ai_review&.status_completed?))
  end

  # Tela "Gravar": o vídeo é obrigatório e o checklist de segurança também.
  def validate_recording
    errors.add(:base, "Grave ou escolha um vídeo da manobra.") unless clip.attached? || @clip_problem
    errors.add(:base, "Complete o checklist de segurança antes de enviar.") unless checklist_complete?
  end

  def validate_clip
    blob = clip.blob

    errors.add(:base, clip_problem(:format)) unless CLIP_CONTENT_TYPES.include?(blob.content_type)
    errors.add(:base, clip_problem(:size)) if blob.byte_size > self.class.max_clip_bytes
    # A duração não tem limite: a tela só sugere até max_clip_seconds (40s).
  end

  def schedule_transcode
    @clip_uploaded = false
    TranscodeClipJob.perform_later(self) if clip.attached?
  end
end
