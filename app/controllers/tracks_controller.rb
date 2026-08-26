# Mapa da Trilha: a tela central do app.
class TracksController < ApplicationController
  before_action :require_age_gate
  before_action :require_diagnosis

  def show
    progression.sync!
    @learning_modules = LearningModule.ordered.includes(:maneuvers)
    @current_maneuver = progression.current_maneuver
    @comeback_due     = current_user.away_for_days.to_i >= 14
  end
end
