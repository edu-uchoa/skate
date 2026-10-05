# "Quero ser mentor": a pessoa pede acesso de mentor e espera a aprovação de um
# mentor em /mentor/pedidos. Enquanto isso, segue usando o app como aprendiz.
class MentorApplicationsController < ApplicationController
  before_action :redirect_mentor

  def new
    render :pending if current_user.mentor_requested?
  end

  def create
    if current_user.request_mentor(**application_params)
      redirect_to new_mentor_application_path, notice: "Pedido enviado! Um mentor da equipe vai analisar."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_mentor
    redirect_to mentor_zine_path if current_user.mentor_access?
  end

  def application_params
    attrs = params.require(:mentor_application).permit(:birth_year, :note)
    { birth_year: attrs[:birth_year], note: attrs[:note] }
  end
end
