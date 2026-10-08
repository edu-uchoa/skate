class ManeuverProgress < ApplicationRecord
  belongs_to :user
  belongs_to :maneuver

  # completed: o mentor deu a devolutiva. skipped: a pessoa avançou sem a devolutiva
  # ("Avançar para a próxima tarefa"); fica liberado e destrava o próximo nó, mas não
  # ganha o check.
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
