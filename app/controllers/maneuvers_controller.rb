class ManeuversController < ApplicationController
  before_action :redirect_mentor_account # conta de mentor usa a área do mentor
  before_action :require_onboarding

  def show
    @maneuver = Maneuver.includes(:instruction_steps, :learning_module, :prerequisite).find_by!(slug: params[:slug])
    @status   = progression.sync!.status_for(@maneuver)
    @locked   = @status == "locked"
  end

  # "Avançar para a próxima tarefa" sem a devolutiva do mentor (a tela pergunta
  # antes): a tarefa fica pulada, a seta da trilha anda e a próxima tarefa abre.
  def skip
    maneuver = Maneuver.find_by!(slug: params[:slug])
    if progression.sync!.skip!(maneuver)
      flash[:notice] = "Tarefa #{maneuver.code} pulada. Ela continua liberada para você treinar quando quiser."
    end

    next_maneuver = maneuver.next_in_track
    redirect_to next_maneuver ? maneuver_path(next_maneuver) : track_path
  end
end
