# Página da ofensiva (botão no Perfil e na Trilha): como funciona, situação atual,
# últimas sessões e o campo para justificar uma parada.
class StreaksController < ApplicationController
  before_action :redirect_mentor_account # conta de mentor usa a área do mentor
  before_action :require_onboarding

  def show
    @streak = Streak.new(current_user)
    @justification = StreakJustification.new(user: current_user)
  end
end
