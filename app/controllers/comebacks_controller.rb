# Rampa de retorno para quem ficou um tempo fora.
class ComebacksController < ApplicationController
  before_action :require_age_gate

  def new
    @comeback = current_user.comebacks.build
  end

  def create
    @comeback = current_user.comebacks.build(comeback_params.merge(days_away: current_user.away_for_days))

    if @comeback.save
      @warmups = @comeback.warmup_maneuvers
      render :created
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def comeback_params
    params.require(:comeback).permit(:reason)
  end
end
