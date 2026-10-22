# "Meus dados" (LGPD, art. 18, II e V): uma cópia, em JSON, de tudo o que o FlipaAi
# guarda sobre a pessoa. Fica de fora só o que é segredo de segurança (token de login,
# senha embaralhada, códigos de recuperação) e o código interno da conta Google.
# Os vídeos vêm como endereço: abrem logado, na própria conta.
class DataExport
  def initialize(user, clip_url:)
    @user = user
    @clip_url = clip_url # lambda: TrainingSession -> endereço do vídeo
  end

  def as_json(*)
    {
      gerado_em: Time.current.iso8601,
      sobre: "Cópia dos seus dados no FlipaAi. Veja o que cada parte significa na Política de Privacidade (/privacidade).",
      conta: account,
      diagnostico: diagnosis,
      trilha: progress,
      treinos_e_videos: training_sessions,
      chat: chat,
      ofensiva: { sessoes: @user.skate_sessions.order(:skated_on).map { |s| { dia: s.skated_on, validada_em: s.validated_at } },
                  justificativas: @user.streak_justifications.order(:created_at).map { |j| j.slice(:reason, :status, :created_at, :reviewed_at) } },
      roles_marcados: @user.meetups.order(:starts_at).map { |m| m.slice(:place_name, :note, :latitude, :longitude, :starts_at, :ends_at) },
      pedidos_de_ajuda: @user.support_requests.order(:created_at).map { |r| r.slice(:kind, :message, :contact, :status, :created_at) },
      retornos: @user.comebacks.order(:created_at).map { |c| c.slice(:days_away, :reason, :created_at) },
      devolutivas_que_voce_escreveu: @user.given_reviews.count,
      # Mentor: as notas que recebeu dos aprendizes (sem dizer de quem, como no Perfil).
      notas_que_voce_recebeu: @user.given_reviews.rated.order(:rated_at).map { |r| { rolamentos: r.rating, mensagem: r.rating_comment, em: r.rated_at } }
    }
  end

  def to_json(*) = JSON.pretty_generate(as_json)

  def filename = "flipaai-meus-dados-#{Date.current.iso8601}.json"

  private

  def account
    @user.slice(:email, :phone, :nickname, :nickname_tag, :birth_year, :role, :time_zone,
                :registered_at, :terms_accepted_at, :last_seen_at, :mentor_requested_at, :mentor_request_note, :mentor_bio)
         .merge(nickname_completo: @user.handle, entra_com_google: @user.google?,
                avatar: @user.avatar_options, skate: @user.board_options)
  end

  def diagnosis
    diagnosis = @user.diagnosis
    return if diagnosis.nil?
    diagnosis.slice(:level, :setup, :completed_at).merge(travas: diagnosis.diagnosis_blockers.map(&:kind))
  end

  def progress
    @user.maneuver_progresses.includes(:maneuver).order(:created_at).map do |progress|
      { tarefa: progress.maneuver.label, status: progress.status, tentativas: progress.attempts_count, concluida_em: progress.completed_at }
    end
  end

  def training_sessions
    @user.training_sessions.includes(:maneuver, :mentor, :ai_review, :clip_accesses, clip_attachment: :blob).order(:created_at).map do |session|
      review = session.ai_review
      {
        tarefa: session.maneuver.label, marcado_para: session.scheduled_on, periodo: session.period,
        status: session.status, resultado: session.outcome, anotacoes: session.notes, lugar: session.location_name,
        enviado_em: session.submitted_at,
        video: (@clip_url.call(session) if session.clip.attached?),
        video_sera_apagado_em: (session.clip_expires_at if session.clip.attached?),
        mentor_escolhido: session.mentor&.handle,
        devolutiva: (review.slice(:headline, :strengths, :mistake, :next_focus, :completed_at, :revised_at) if review&.status_completed?),
        sua_nota_ao_mentor: ({ rolamentos: review.rating, mensagem: review.rating_comment, em: review.rated_at } if review&.rating),
        quem_assistiu: session.clip_accesses.map { |access| { em: access.created_at, mentor: access.viewer&.handle || "mentor" } }
      }
    end
  end

  def chat
    conversation = @user.conversation
    return [] if conversation.nil?
    conversation.messages.includes(:author).map do |message|
      { de: (message.author_id == @user.id ? "você" : "equipe de mentores"), texto: message.body, em: message.created_at }
    end
  end
end
