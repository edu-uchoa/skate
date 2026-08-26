class ManeuverProgress < ApplicationRecord
  belongs_to :user
  belongs_to :maneuver

  enum :status, { locked: 0, available: 1, in_progress: 2, completed: 3 }, prefix: true

  validates :maneuver_id, uniqueness: { scope: :user_id }

  scope :done, -> { where(status: :completed) }

  def complete!
    update!(status: :completed, completed_at: Time.current)
  end

  def unlocked? = !status_locked?
end
