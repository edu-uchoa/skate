class AiReview < ApplicationRecord
  belongs_to :training_session
  has_one :user, through: :training_session

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }, prefix: true

  def finished? = status_completed? || status_failed?

  def apply!(result)
    update!(
      status: :completed,
      headline: result[:headline],
      strengths: result[:strengths],
      mistake: result[:mistake],
      next_focus: result[:next_focus],
      raw_response: result[:raw].to_s,
      completed_at: Time.current
    )
    training_session.update!(status: :analyzed)
  end

  def fail!(message)
    update!(status: :failed, error_message: message.to_s.truncate(255))
  end
end
