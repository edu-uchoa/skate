# Rolê marcado no mapa de Picos: onde e quando a pessoa vai andar de skate.
#
# Fica no mapa até o horário de fim e pode ser compartilhado com os amigos por um
# link secreto (/role/:token), que mostra só o lugar, o dia e o horário: nunca o
# nome, o e-mail ou o telefone de quem marcou. Depois que acaba, some do banco.
class Meetup < ApplicationRecord
  belongs_to :user
  has_secure_token :share_token, length: 24

  PLACE_LENGTH   = 80
  NOTE_LENGTH    = 140
  MAX_HOURS      = 12
  MAX_DAYS_AHEAD = 60
  MAX_ACTIVE     = 5 # rolês marcados ao mesmo tempo, por pessoa

  WEEKDAYS = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze

  # Campos do formulário: o dia e os horários, no fuso de quem marca.
  attribute :day, :date
  attribute :start_time, :string
  attribute :end_time, :string

  scope :active,   -> { where("ends_at > ?", Time.current) }
  scope :expired,  -> { where(ends_at: ..Time.current) }
  scope :upcoming, -> { active.order(:starts_at) }

  before_validation :apply_schedule
  normalizes :place_name, with: ->(name) { name.squish }
  normalizes :note, with: ->(note) { note.squish.presence }

  validate :validate_place
  validate :validate_schedule
  validate :validate_active_limit, on: :create

  def self.purge_expired! = expired.delete_all

  # "Sáb, 12/10 · 16h às 18h", no fuso de quem marcou o rolê (começa e acaba no mesmo dia).
  def schedule_label
    starts = starts_at.in_time_zone(zone)
    "#{WEEKDAYS[starts.wday]}, #{starts.strftime("%d/%m")} · #{hour_label(starts)} às #{hour_label(ends_at.in_time_zone(zone))}"
  end

  def google_maps_url = "https://www.google.com/maps/search/?api=1&query=#{latitude},#{longitude}"

  def happening_now? = starts_at <= Time.current && ends_at > Time.current

  private

  def zone = ActiveSupport::TimeZone[user&.time_zone.to_s] || ActiveSupport::TimeZone["America/Sao_Paulo"]

  def hour_label(time) = time.min.zero? ? "#{time.hour}h" : time.strftime("%-Hh%M")

  def apply_schedule
    return if day.blank?

    self.starts_at = parse_time(start_time)
    self.ends_at   = parse_time(end_time)
  end

  def parse_time(value)
    return unless value.to_s.match?(/\A\d{1,2}:\d{2}\z/)

    zone.parse("#{day.iso8601} #{value}")
  rescue ArgumentError
    nil
  end

  def validate_place
    errors.add(:base, "Diga onde vai ser o rolê.") if place_name.blank?
    errors.add(:base, "O nome do lugar pode ter até #{PLACE_LENGTH} letras.") if place_name.to_s.length > PLACE_LENGTH
    errors.add(:base, "O recado pode ter até #{NOTE_LENGTH} letras.") if note.to_s.length > NOTE_LENGTH
    unless latitude.to_f.between?(-90, 90) && longitude.to_f.between?(-180, 180) && latitude.present? && longitude.present?
      errors.add(:base, "Toque no mapa ou escolha um pico para marcar o lugar.")
    end
  end

  def validate_schedule
    return errors.add(:base, "Escolha o dia e os horários do rolê.") if starts_at.blank? || ends_at.blank?

    if ends_at <= starts_at
      errors.add(:base, "O horário de fim precisa ser depois do começo.")
    elsif ends_at <= Time.current
      errors.add(:base, "Esse horário já passou. Escolha um que ainda vai acontecer.")
    elsif ends_at - starts_at > MAX_HOURS.hours
      errors.add(:base, "Um rolê pode durar até #{MAX_HOURS} horas.")
    elsif starts_at > MAX_DAYS_AHEAD.days.from_now
      errors.add(:base, "Marque rolês para os próximos #{MAX_DAYS_AHEAD} dias.")
    end
  end

  def validate_active_limit
    return unless user && user.meetups.active.count >= MAX_ACTIVE

    errors.add(:base, "Você já tem #{MAX_ACTIVE} rolês marcados. Cancele um para marcar outro.")
  end
end
