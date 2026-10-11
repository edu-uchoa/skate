module Mentor
  # Aba "Ofensivas": justificativas de parada esperando avaliação. Aprovar mantém
  # a ofensiva do aprendiz; recusar faz a parada contar (Streak).
  class StreakJustificationsController < BaseController
    def index
      @justifications = StreakJustification.for_review(current_user).includes(:user)
    end

    def update
      justification = StreakJustification.for_review(current_user).find(params[:id])
      approve = params[:decision] == "approve"
      justification.decide!(current_user, approve: approve)

      redirect_to mentor_streak_justifications_path,
                  notice: approve ? "Ofensiva mantida. O aprendiz vê a decisão na página da ofensiva." : "Justificativa recusada."
    end
  end
end
