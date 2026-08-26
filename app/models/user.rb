class User < ApplicationRecord
  has_secure_token :token

  has_one  :diagnosis, dependent: :destroy
  has_many :access_codes, dependent: :destroy
  has_many :maneuver_progresses, dependent: :destroy
  has_many :maneuvers, through: :maneuver_progresses
  has_many :training_sessions, dependent: :destroy
  has_many :support_requests, dependent: :destroy
  has_many :comebacks, dependent: :destroy

  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :phone, with: ->(value) { value.to_s.gsub(/\D/, "").presence }

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :birth_year,
            numericality: { only_integer: true, greater_than: 1900, less_than_or_equal_to: -> (_) { Date.current.year } },
            allow_nil: true

  scope :anonymous, -> { where(registered_at: nil) }
  scope :registered, -> { where.not(registered_at: nil) }

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

  # Transforma o perfil temporário em conta salva.
  def register!(destination)
    if destination.to_s.include?("@")
      self.email = destination
    else
      self.phone = destination
    end
    self.registered_at = Time.current
    save!
  end
end
