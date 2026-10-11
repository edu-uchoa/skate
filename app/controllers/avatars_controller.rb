# Salva o avatar de skatista do Perfil. Só opções da lista entram (Avatar).
class AvatarsController < ApplicationController
  def update
    current_user.update!(avatar_options: Avatar.new(params.fetch(:avatar, {}).permit(*Avatar::DEFAULTS.keys).to_h).to_h)
    redirect_to my_account_path(anchor: "personalizar"), notice: "Avatar salvo!"
  end
end
