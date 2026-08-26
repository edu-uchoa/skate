class AccessCode < ApplicationRecord
  MAX_ATTEMPTS = 5
  TTL          = 10.minutes
  LENGTH       = 6

  belongs_to :user

  enum :channel, { email: 0, whatsapp: 1 }, validate: true

  scope :usable, -> { where(consumed_at: nil).where(expires_at: Time.current..) }

  attr_reader :code

  # Gera e "envia" um código de 6 dígitos. A entrega real (e-mail/WhatsApp)
  # entra em AccessCodeDelivery — hoje só loga em desenvolvimento.
  def self.issue!(user:, destination:)
    code = format("%0#{LENGTH}d", SecureRandom.random_number(10**LENGTH))

    record = create!(
      user: user,
      destination: destination,
      channel: destination.to_s.include?("@") ? :email : :whatsapp,
      code_digest: BCrypt::Password.create(code),
      expires_at: TTL.from_now
    )
    record.instance_variable_set(:@code, code)
    record
  end

  def verify(candidate)
    return false if consumed? || expired? || attempts >= MAX_ATTEMPTS

    increment!(:attempts)

    if BCrypt::Password.new(code_digest) == candidate.to_s.strip
      update!(consumed_at: Time.current)
      true
    else
      false
    end
  end

  def consumed? = consumed_at.present?
  def expired?  = expires_at.past?
end
