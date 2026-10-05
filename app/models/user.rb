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

  # Mentor vê os vídeos de todos os aprendizes e responde as devolutivas. Ninguém vira
  # mentor sozinho: no cadastro a pessoa faz um pedido (#request_mentor) e um mentor
  # aprova na área do mentor. O primeiro mentor é promovido pelo terminal (lib/tasks/mentor.rake).
  enum :role, { learner: 0, mentor: 1 }, prefix: true

  MENTOR_MINIMUM_AGE = 18
  MENTOR_NOTE_LENGTH = 500

  scope :mentor_requests, -> { role_learner.where.not(mentor_requested_at: nil).order(:mentor_requested_at) }

  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :phone, with: ->(value) { value.to_s.gsub(/\D/, "").presence }

  validates :birth_year,
            numericality: { only_integer: true, greater_than: 1900, less_than_or_equal_to: ->(_) { Date.current.year } },
            allow_nil: true
  validate :validate_contact
  validate :validate_password, if: :registered?

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

  def can_sign_in? = registered? && password_digest.present?

  # Invalida o cookie em todos os aparelhos.
  def sign_out_everywhere! = regenerate_token

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

  def approve_mentor! = update!(role: :mentor, mentor_requested_at: nil)

  def reject_mentor! = update!(mentor_requested_at: nil, mentor_request_note: nil)

  private

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

  def validate_password
    return if password.nil? && password_digest.present?
    self.class.password_problem(password, password_confirmation)&.then { errors.add(:base, it) }
  end
end
