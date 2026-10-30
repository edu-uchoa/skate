class User < ApplicationRecord
  PASSWORD_LENGTH = 8..72

  has_secure_token :token
  has_secure_password validations: false

  has_one  :diagnosis, dependent: :destroy
  has_many :access_codes, dependent: :destroy
  has_many :maneuver_progresses, dependent: :destroy
  has_many :maneuvers, through: :maneuver_progresses
  has_many :training_sessions, dependent: :destroy
  has_many :support_requests, dependent: :destroy
  has_many :comebacks, dependent: :destroy
  has_many :given_reviews, class_name: "AiReview", foreign_key: :reviewer_id,
                           inverse_of: :reviewer, dependent: :nullify # devolutivas que respondeu como mentor
  has_many :clip_accesses, foreign_key: :viewer_id, inverse_of: :viewer, dependent: :nullify # vídeos de outros que assistiu
  has_many :meetups, dependent: :delete_all # rolês marcados no mapa de Picos
  has_many :skate_sessions, dependent: :delete_all # sessões da ofensiva (Streak)
  has_many :streak_justifications, dependent: :delete_all # paradas justificadas, avaliadas por mentor
  has_one  :conversation, foreign_key: :learner_id, inverse_of: :learner, dependent: :destroy # chat com os mentores
  has_many :messages, foreign_key: :author_id, inverse_of: :author, dependent: :nullify      # o que escreveu no chat
  has_many :chosen_sessions, class_name: "TrainingSession", foreign_key: :mentor_id,
                             inverse_of: :mentor, dependent: :nullify # vídeos em que um aprendiz o escolheu para avaliar
  has_many :mentor_notes, foreign_key: :learner_id, inverse_of: :learner, dependent: :delete_all # observações dos mentores sobre ele
  has_many :written_mentor_notes, class_name: "MentorNote", foreign_key: :author_id,
                                  inverse_of: :author, dependent: :nullify # observações que escreveu como mentor
  # Apagar a conta tira o e-mail da lista de acesso: para voltar, precisa ser liberado de novo.
  after_destroy { AllowedEmail.where(email: email).delete_all if email }

  # Mentor vê os vídeos de todos os aprendizes e responde as devolutivas. Ninguém vira
  # mentor sozinho: no cadastro a pessoa faz um pedido (#request_mentor) e só um
  # administrador aprova. Administrador faz tudo que o mentor faz, mais aprovar e
  # remover mentores, e só é criado pelo terminal (lib/tasks/admin.rake).
  enum :role, { learner: 0, mentor: 1, admin: 2 }, prefix: true
  belongs_to :mentor_approved_by, class_name: "User", optional: true
  has_many :approved_mentors, class_name: "User", foreign_key: :mentor_approved_by_id,
                              inverse_of: :mentor_approved_by, dependent: :nullify # mentores que aprovou

  MENTOR_MINIMUM_AGE = 18
  MENTOR_NOTE_LENGTH = 500
  MENTOR_BIO_LENGTH  = 300

  scope :mentor_requests, -> { role_learner.where.not(mentor_requested_at: nil).order(:mentor_requested_at) }

  # Resumo profissional do mentor: aparece para os aprendizes na hora de escolher quem
  # avalia o vídeo. Sem contato de fora do app (há aprendizes menores de idade).
  normalizes :mentor_bio, with: ->(value) { value.to_s.strip.presence }
  validate :validate_mentor_bio, if: :will_save_change_to_mentor_bio?

  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :phone, with: ->(value) { value.to_s.gsub(/\D/, "").presence }

  validates :birth_year,
            numericality: { only_integer: true, greater_than: 1900, less_than_or_equal_to: ->(_) { Date.current.year } },
            allow_nil: true
  validate :validate_contact
  # Quem entra pelo Google não tem senha.
  validate :validate_password, if: -> { registered? && google_uid.blank? }

  # Nickname#0000: como a pessoa aparece para os outros usuários e para os mentores.
  # O nickname pode repetir; os 4 números depois do "#" separam os iguais.
  NICKNAME_LENGTH = 3..20
  NICKNAME_FORMAT = /\A[\p{L}\p{N}_.-]+\z/ # letras (com acento), números, "_", "." e "-"
  NICKNAME_TAG    = /\A\d{4}\z/

  normalizes :nickname, with: ->(value) { value.to_s.strip.presence }
  normalizes :nickname_tag, with: ->(value) { value.to_s.strip.delete_prefix("#").presence }
  before_validation { self.nickname_key = nickname&.downcase }
  validate :validate_nickname, if: -> { nickname.present? || nickname_tag.present? }

  scope :anonymous, -> { where(registered_at: nil) }
  scope :registered, -> { where.not(registered_at: nil) }

  # Contato (e-mail ou telefone/WhatsApp) digitado no cadastro e no login.
  def self.contact_attribute(contact) = contact.to_s.include?("@") ? :email : :phone

  def self.normalize_contact(contact)
    attribute = contact_attribute(contact)
    normalize_value_for(attribute, contact)
  end

  def self.valid_contact?(contact)
    value = normalize_contact(contact).to_s
    if contact_attribute(contact) == :email
      value.match?(URI::MailTo::EMAIL_REGEXP)
    else
      value.length.between?(10, 13)
    end
  end

  def self.find_registered_by_contact(contact)
    return unless valid_contact?(contact)
    registered.find_by(contact_attribute(contact) => normalize_contact(contact))
  end

  MINIMUM_AGE = 13
  SUPERVISION_AGE = 18

  def anonymous?  = registered_at.nil?
  def registered? = !anonymous?

  def age
    return if birth_year.blank?
    Date.current.year - birth_year
  end

  def old_enough?         = age.present? && age >= MINIMUM_AGE
  def needs_supervision?  = age.present? && age.between?(MINIMUM_AGE, SUPERVISION_AGE - 1)
  def accepted_terms?     = terms_accepted_at.present?
  def onboarded?          = accepted_terms? && diagnosis&.completed?

  # Sessão marcada mais próxima que ainda não aconteceu.
  def next_training_session
    training_sessions.scheduled.where(scheduled_on: Date.current..).order(:scheduled_on).first
  end

  def away_for_days
    last = training_sessions.where.not(submitted_at: nil).maximum(:submitted_at)
    return if last.nil?
    (Time.current.to_date - last.to_date).to_i
  end

  # Cadastro: e-mail ou telefone + senha.
  def self.register(contact:, password:, password_confirmation:)
    new(password: password, password_confirmation: password_confirmation, registered_at: Time.current).tap do |user|
      user.contact = contact
      user.save
    end
  end

  # Regra de senha; nil quando está tudo certo.
  def self.password_problem(password, confirmation)
    if password.blank?
      "Crie uma senha."
    elsif !PASSWORD_LENGTH.cover?(password.bytesize)
      "A senha precisa ter entre #{PASSWORD_LENGTH.min} e #{PASSWORD_LENGTH.max} caracteres."
    elsif !confirmation.nil? && password != confirmation
      "A confirmação não confere com a senha."
    end
  end

  # Login: nil quando o contato não existe ou a senha não confere.
  def self.authenticate_by_contact(contact, password)
    return unless valid_contact?(contact) && password.present?
    registered.authenticate_by(contact_attribute(contact) => normalize_contact(contact), password: password)
  end

  # E-mail ou telefone com que a conta entra.
  def contact = email || phone

  def contact=(value)
    @contact_input = value.to_s.strip
    self.email = self.phone = nil
    public_send("#{self.class.contact_attribute(@contact_input)}=", @contact_input)
  end

  def can_sign_in? = registered? && (password_digest.present? || google_uid.present?)

  # "skatista#0420", como a pessoa aparece no app; nil enquanto não escolheu.
  def handle = ("#{nickname}##{nickname_tag}" if nickname.present? && nickname_tag.present?)

  def google? = google_uid.present?

  # Um dos 4 números ainda livres para esse nickname, sorteado (nil se acabaram).
  # Busca do painel do super administrador: "nick#0420" acha a conta exata; outro texto
  # procura no nickname, no e-mail e (se tiver números) no telefone.
  def self.search(query)
    query = query.to_s.strip
    return all if query.empty?

    if (exact = query.match(/\A(.+)#(\d{4})\z/))
      return where(nickname_key: exact[1].downcase, nickname_tag: exact[2])
    end

    text = "%#{sanitize_sql_like(query.downcase)}%"
    found = where("users.nickname_key LIKE :text OR users.email LIKE :text", text: text)
    digits = query.gsub(/\D/, "")
    digits.empty? ? found : found.or(where("users.phone LIKE ?", "%#{sanitize_sql_like(digits)}%"))
  end

  def self.free_nickname_tag(nickname, except: nil)
    taken = where(nickname_key: nickname.to_s.strip.downcase).where.not(id: except).pluck(:nickname_tag)
    ((1..9999).map { |number| format("%04d", number) } - taken).sample
  end

  # Conta Google nova só com e-mail @gmail.com. Com e-mail de escola, de empresa ou de
  # outro provedor, quem controla o domínio pode criar outra conta Google com o mesmo
  # endereço; o Gmail nunca passa para outra pessoa um endereço que já existiu.
  GOOGLE_EMAIL_DOMAINS = %w[gmail.com googlemail.com].freeze
  class_attribute :google_email_domains, instance_accessor: false, default: GOOGLE_EMAIL_DOMAINS # nos testes, mais o example.com

  def self.google_email_allowed?(email) = email.to_s.strip.downcase.split("@").last.to_s.in?(google_email_domains)

  # Por que o Google não deixou entrar (GoogleSessionsController mostra o aviso e
  # registra no log). reason: :unverified_email, :email_domain, :not_invited ou :other_google.
  class GoogleRefusal < StandardError
    attr_reader :reason, :account

    def initialize(reason, account = nil)
      @reason  = reason
      @account = account # a conta do FlipaAi envolvida, quando há
      super(reason.to_s)
    end
  end

  # Entrar com o Google: devolve a conta da pessoa ou cria uma nova. Só aceita e-mail
  # confirmado pelo Google (a gem só preenche info.email quando o Google confirmou).
  # A conta é achada pelo código da conta Google (uid), que não muda nem passa para
  # outra pessoa; o e-mail só conta na primeira entrada. Recusa com GoogleRefusal.
  def self.from_google(auth)
    uid   = auth&.uid.to_s
    email = auth&.info&.email.to_s.strip.downcase
    raise GoogleRefusal, :unverified_email if uid.blank? || email.blank?

    account = find_by(google_uid: uid)
    raise GoogleRefusal.new(:not_invited, account) if account && !account.access_allowed?

    account || first_google_sign_in(uid, email)
  rescue ActiveRecord::RecordNotUnique
    find_by(google_uid: uid) || raise(GoogleRefusal, :other_google)
  end

  # Primeira entrada com esta conta Google, só com e-mail @gmail.com e liberado na lista
  # de acesso (antes de criar a conta: de quem não foi liberado, nada fica guardado).
  # Conta antiga com o mesmo e-mail (cadastro com senha, sem Google) é a mesma pessoa:
  # o histórico, os vídeos e o XP continuam. Conta com esse e-mail já ligada a outra
  # conta Google não troca de dono.
  def self.first_google_sign_in(uid, email)
    raise GoogleRefusal, :email_domain unless google_email_allowed?(email)
    raise GoogleRefusal, :not_invited unless new(email: email, google_uid: uid).access_allowed?

    account = find_by(email: email)
    raise GoogleRefusal.new(:other_google, account) if account&.google?

    account&.tap { it.link_google!(uid) } || create!(email: email, google_uid: uid, registered_at: Time.current)
  end
  private_class_method :first_google_sign_in

  # Liga a conta ao Google. A senha antiga deixa de valer e as outras sessões caem:
  # daqui em diante só entra quem tem a conta Google (que confirmou o e-mail).
  def link_google!(uid)
    transaction do
      update!(google_uid: uid, password_digest: nil, registered_at: registered_at || Time.current)
      regenerate_token
    end
  end

  # Escolher (ou trocar) o nickname. Sem número, o app sorteia um livre. Devolve false com erros.
  def choose_nickname(nickname:, tag: nil)
    self.nickname = nickname
    self.nickname_tag = tag.presence || (nickname_tag if nickname_key_was == self.nickname.to_s.downcase) ||
                        self.class.free_nickname_tag(self.nickname, except: id)
    save
  end

  # Invalida o cookie em todos os aparelhos. Sem validações: sair nunca pode falhar.
  def sign_out_everywhere! = update_column(:token, self.class.generate_unique_secure_token)

  def mentor_requested? = role_learner? && mentor_requested_at.present?

  # Pedido de mentor: precisa ter 18+ (muitos aprendizes são menores) e contar a
  # experiência no skate, para quem aprova saber quem é. Devolve false com erros.
  def request_mentor(birth_year:, note:)
    self.birth_year = birth_year.presence
    self.mentor_request_note = note.to_s.strip.first(MENTOR_NOTE_LENGTH).presence

    if (problem = mentor_request_problem)
      errors.add(:base, problem)
      return false
    end

    update(mentor_requested_at: Time.current)
  end

  # Super administrador: o dono do app, que entra no painel restrito (/painel) e pode
  # remover contas, vídeos e devolutivas. Não é um papel guardado no banco: é a conta
  # Google que o dono autorizou com uma concessão assinada na máquina dele (SuperAdmin).
  # Ninguém vira super admin pelo app, e o login com senha (contas antigas) não dá esse acesso.
  def super_admin? = SuperAdmin.granted?(self)

  # Pode usar o app? No app publicado (config.x.flipaai.invite_only), só quem tem o
  # e-mail na lista de acesso (AllowedEmail) e o super admin, que entra mesmo com a
  # lista vazia (depois de um banco novo, é ele quem libera os outros).
  def access_allowed?
    !Rails.configuration.x.flipaai.invite_only || (email.present? && AllowedEmail.exists?(email: email)) || super_admin?
  end

  # Funções de administrador (aprovar e remover mentores, apagar vídeos de aprendizes).
  def admin_access? = role_admin? || super_admin?

  # Pode entrar na área do mentor (ver vídeos de aprendizes e responder).
  def mentor_access? = role_mentor? || admin_access?

  # Conta de trabalho de mentor (mentor aprovado ou administrador): usa o app só pela
  # área do mentor, sem Trilha, Picos e Gravar. O super admin, que também treina como
  # aprendiz, continua com o app de aprendiz e entra na área do mentor pelo topo.
  def mentor_account? = role_mentor? || role_admin?

  # Mentores que o aprendiz pode escolher para avaliar o vídeo: mentores e
  # administradores com nickname (é como o aprendiz reconhece quem escolheu), menos o
  # super administrador (o dono do app).
  def self.available_mentors
    where(role: %i[mentor admin]).where.not(nickname: nil).order(:nickname_key, :id).reject(&:super_admin?)
  end

  # O mentor escolhido, se ele ainda está na lista; senão nil (o vídeo vai para qualquer mentor).
  def self.available_mentor(id)
    available_mentors.find { |mentor| mentor.id == id.to_i } if id.present?
  end

  # by: o administrador que aprovou (nil quando foi pelo terminal).
  def approve_mentor!(by: nil)
    update!(role: :mentor, mentor_requested_at: nil, mentor_approved_by: by, mentor_approved_at: Time.current)
  end

  def reject_mentor! = update!(mentor_requested_at: nil, mentor_request_note: nil)

  # Tira o acesso aos vídeos na hora: volta a aprendiz e derruba as sessões abertas.
  # Os vídeos em que ele era o escolhido passam para qualquer mentor.
  def revoke_mentor!
    transaction do
      update!(role: :learner, mentor_approved_by: nil, mentor_approved_at: nil)
      chosen_sessions.update_all(mentor_id: nil)
      sign_out_everywhere!
    end
  end

  private

  def validate_mentor_bio
    return if mentor_bio.nil?

    if mentor_bio.length > MENTOR_BIO_LENGTH
      errors.add(:base, "O resumo passa de #{MENTOR_BIO_LENGTH} caracteres. Deixe mais curto.")
    elsif Message::CONTACT_PATTERNS.any? { |pattern| mentor_bio.match?(pattern) }
      errors.add(:base, "Por segurança, o resumo não pode ter telefone, e-mail, links ou @ de redes sociais.")
    end
  end

  def mentor_request_problem
    if birth_year.blank? || !birth_year.between?(1900, Date.current.year)
      "Informe um ano de nascimento válido."
    elsif age < MENTOR_MINIMUM_AGE
      "Para ser mentor é preciso ter #{MENTOR_MINIMUM_AGE} anos ou mais."
    elsif mentor_request_note.blank?
      "Conte um pouco da sua experiência no skate."
    end
  end

  def validate_contact
    if @contact_input && contact.blank?
      errors.add(:base, @contact_input.empty? ? "Informe um e-mail ou telefone." : "Informe um e-mail ou telefone válido.")
    elsif email_changed? && email && !email.match?(URI::MailTo::EMAIL_REGEXP)
      errors.add(:base, "Informe um e-mail válido.")
    elsif phone_changed? && phone && !phone.length.between?(10, 13)
      errors.add(:base, "Informe um telefone com DDD (ex.: 61 90000-0000).")
    elsif email_changed? && email && User.where.not(id: id).exists?(email: email)
      errors.add(:base, "Esse e-mail já tem uma conta. Use \"Entrar\".")
    elsif phone_changed? && phone && User.where.not(id: id).exists?(phone: phone)
      errors.add(:base, "Esse telefone já tem uma conta. Use \"Entrar\".")
    elsif registered? && contact.blank?
      errors.add(:base, "Informe um e-mail ou telefone.")
    end
  end

  def validate_nickname
    if nickname.blank?
      errors.add(:base, "Escolha um nickname.")
    elsif !NICKNAME_LENGTH.cover?(nickname.length)
      errors.add(:base, "O nickname precisa ter de #{NICKNAME_LENGTH.min} a #{NICKNAME_LENGTH.max} caracteres.")
    elsif !nickname.match?(NICKNAME_FORMAT)
      errors.add(:base, "Use só letras, números, \"_\", \".\" e \"-\" no nickname (sem espaço).")
    elsif nickname.scan(/\d/).size >= 8
      errors.add(:base, "Por segurança, o nickname não pode parecer um telefone.")
    elsif nickname_tag.blank?
      errors.add(:base, "Todos os números para esse nickname já foram usados. Tente outro nickname.")
    elsif !nickname_tag.match?(NICKNAME_TAG) || nickname_tag == "0000"
      errors.add(:base, "O número depois do # precisa ter 4 dígitos, de 0001 a 9999.")
    elsif User.where.not(id: id).exists?(nickname_key: nickname_key, nickname_tag: nickname_tag)
      errors.add(:base, "#{handle} já existe. Escolha outro número ou deixe o app sortear.")
    end
  end

  def validate_password
    return if password.nil? && password_digest.present?
    self.class.password_problem(password, password_confirmation)&.then { errors.add(:base, it) }
  end
end
