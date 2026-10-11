# Justificar uma parada da ofensiva. Uma por parada; um mentor avalia
# (Mentor::StreakJustificationsController) e, até lá, a ofensiva fica guardada.
class StreakJustificationsController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create

  def create
    @streak = Streak.new(current_user)
    unless @streak.can_justify?
      return redirect_to streak_path, alert: "Não há parada para justificar agora."
    end

    @justification = StreakJustification.new(user: current_user, reason: params.dig(:streak_justification, :reason))
    if @justification.save
      redirect_to streak_path(anchor: "justificar"), notice: "Justificativa enviada! Sua ofensiva fica guardada até um mentor avaliar."
    else
      render "streaks/show", status: :unprocessable_entity
    end
  end
end
