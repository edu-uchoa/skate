# "Apagar minha conta" (LGPD, art. 18, VI): a própria pessoa apaga a conta e tudo dela
# (vídeos, progresso, chat, rolês). Para não ser por engano, pede para digitar APAGAR.
class AccountDeletionsController < ApplicationController
  CONFIRMATION = "APAGAR".freeze

  def show; end

  def destroy
    unless params[:confirmation].to_s.strip.upcase == CONFIRMATION
      flash.now[:alert] = "Digite #{CONFIRMATION} para confirmar."
      return render :show, status: :unprocessable_entity
    end

    user = current_user
    sign_out
    user.destroy!
    Rails.logger.info("[FlipaAi] a conta #{user.id} foi apagada pela própria pessoa")
    redirect_to root_path, notice: "Conta apagada. Seus vídeos, progresso e chat saíram do FlipaAi."
  end
end
