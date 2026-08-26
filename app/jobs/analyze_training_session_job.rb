class AnalyzeTrainingSessionJob < ApplicationJob
  queue_as :default
  retry_on Timeout::Error, wait: :polynomially_longer, attempts: 3

  def perform(training_session)
    review = training_session.ai_review
    return if review.blank? || review.finished?

    review.update!(status: :processing)
    review.apply!(Ai::FallAnalyzer.new(training_session).call)
  rescue StandardError => e
    training_session.ai_review&.fail!(e.message)
    raise
  end
end
