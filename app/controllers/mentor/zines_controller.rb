module Mentor
  # Zine do mentor: os vídeos enviados pelos aprendizes, separados por pessoa.
  # Aba "fila": só os vídeos esperando devolutiva, de quem espera há mais tempo.
  # Aba "todos": todos os vídeos, de quem gravou por último.
  class ZinesController < BaseController
    TABS = %w[fila todos].freeze

    def show
      @tab = TABS.include?(params[:aba]) ? params[:aba] : "fila"

      sessions = learner_clips.includes(user: :diagnosis).recent.to_a
      @learners = @tab == "fila" ? queue_by_learner(sessions) : sessions.group_by(&:user)
    end

    private

    def queue_by_learner(sessions)
      waiting = sessions.select(&:analysis_running?).group_by(&:user)
      waiting.transform_values { |list| list.sort_by { |s| s.ai_review.created_at } }
             .sort_by { |_, list| list.first.ai_review.created_at }
             .to_h
    end
  end
end
