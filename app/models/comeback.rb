class Comeback < ApplicationRecord
  belongs_to :user

  enum :reason, { injury: 0, lost_focus: 1, no_time: 2 }, prefix: true

  validates :reason, presence: true

  # Após uma pausa, a volta é por manobras já dominadas (aquecimento).
  def warmup_maneuvers(limit: 2)
    user.maneuver_progresses.done.includes(:maneuver).order(completed_at: :desc).limit(limit).map(&:maneuver)
  end
end
