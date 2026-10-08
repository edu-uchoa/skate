class ManeuverProgress < ApplicationRecord
  belongs_to :user
  belongs_to :maneuver

  # skipped: ficou antes do ponto de entrada do diagnóstico. Está liberado e destrava
  # o próximo nó, mas não conta como concluído (o check é só para o que foi treinado).
  enum :status, { locked: 0, available: 1, in_progress: 2, completed: 3, skipped: 4 }, prefix: true

  # Estados que destravam o nó seguinte da trilha.
  UNLOCKING = %w[completed skipped].freeze

  validates :maneuver_id, uniqueness: { scope: :user_id }

  scope :done, -> { where(status: :completed) }

  def complete!
    update!(status: :completed, completed_at: Time.current)
  end

  def unlocked? = !status_locked?
end
