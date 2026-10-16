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
      redirect_to(first_time ? install_path : my_account_path, notice: "Pronto! No FlipaAi você é #{current_user.handle}.")
    else
      @suggested_tag = attrs[:tag].presence || current_user.nickname_tag
      render :edit, status: :unprocessable_entity
    end
  end
end
