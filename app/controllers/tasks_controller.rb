# Tarefas da trilha (botão "Tarefas concluídas" do Perfil): as concluídas, de
# forma breve, e as que ainda faltam, com a situação de cada uma.
class TasksController < ApplicationController
  before_action :require_onboarding

  def index
    progression.sync!
    @maneuvers = Maneuver.ordered.includes(:learning_module).to_a
    @current   = progression.current_maneuver
    @done, @pending = @maneuvers.partition { |maneuver| progression.status_for(maneuver) == "completed" }
    @xp = @done.sum { |maneuver| ProfileStats.xp_for(maneuver) }
  end
end
