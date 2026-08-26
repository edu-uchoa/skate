class ManeuversController < ApplicationController
  before_action :require_age_gate

  def show
    @maneuver = Maneuver.includes(:instruction_steps, :learning_module, :prerequisite).find_by!(slug: params[:slug])
    @status   = progression.status_for(@maneuver)
    @locked   = @status == "locked"
  end
end
