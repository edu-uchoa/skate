# Nickname#0000: escolhido logo depois de entrar com o Google pela primeira vez, e
# trocado pelo Perfil quando a pessoa quiser.
class NicknamesController < ApplicationController
  def edit
    @suggested_tag = current_user.nickname_tag || User.free_nickname_tag(current_user.nickname.presence || "skatista")
  end

  def update
    first_time = current_user.handle.nil?
    attrs = params.require(:nickname).permit(:nickname, :tag)

    if current_user.choose_nickname(nickname: attrs[:nickname], tag: attrs[:tag])
      redirect_to(first_time ? first_step_path : my_account_path, notice: "Pronto! No FlipaAi você é #{current_user.handle}.")
    else
      @suggested_tag = attrs[:tag].presence || current_user.nickname_tag
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Conta nova segue direto para as perguntas (idade e diagnóstico); conta antiga
  # que já fez o onboarding volta para a trilha, e a de mentor vai para a fila.
  def first_step_path
    return home_path_for(current_user) if current_user.mentor_account? || current_user.onboarded?
    onboarding_age_gate_path
  end
end
