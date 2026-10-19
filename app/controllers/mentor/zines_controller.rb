module Mentor
  # Zine do mentor: os vídeos enviados pelos aprendizes, separados por pessoa.
  # Aba "fila": os vídeos ainda sem devolutiva (entram assim que chegam), de quem
  # espera há mais tempo; a devolutiva é escrita no próprio cartão.
  # Aba "todos": todos os vídeos, de quem gravou por último; as devolutivas já
  # enviadas podem ser revisadas.
  class ZinesController < BaseController
    TABS = %w[fila todos].freeze

    def show
      @tab = TABS.include?(params[:aba]) ? params[:aba] : "fila"
      TrainingSession.purge_expired_clips! # vídeo que passou de 1 mês sai da fila

      sessions = learner_clips.includes(user: :diagnosis)
      @learners =
        if @tab == "fila"
          sessions.awaiting_review.to_a.sort_by(&:waiting_since).group_by(&:user)
        else
          sessions.recent.to_a.group_by(&:user)
        end
    end
  end
end
