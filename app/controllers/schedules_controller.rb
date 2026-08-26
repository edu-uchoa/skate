# Compromisso privado (primeira sessão) e agendamento da próxima.
class SchedulesController < ApplicationController
  before_action :require_age_gate

  def new
    @maneuver = resolve_maneuver
    @training_session = current_user.training_sessions.build(
      maneuver: @maneuver, scheduled_on: Date.current.next_occurring(:saturday), period: :morning
    )
    @first_commitment = current_user.training_sessions.none?
  end

  def create
    @maneuver = resolve_maneuver
    @training_session = current_user.training_sessions.build(schedule_params.merge(maneuver: @maneuver, status: :scheduled))

    if @training_session.save
      redirect_to track_path, notice: "Compromisso salvo. Te esperamos lá."
    else
      @first_commitment = current_user.training_sessions.none?
      render :new, status: :unprocessable_entity
    end
  end

  private

  def schedule_params
    params.require(:training_session).permit(:scheduled_on, :period, :location_name)
  end

  def resolve_maneuver
    slug = params[:maneuver_slug].presence || params.dig(:training_session, :maneuver_slug)
    (slug && Maneuver.find_by(slug: slug)) || progression.current_maneuver || Maneuver.ordered.first
  end
end
