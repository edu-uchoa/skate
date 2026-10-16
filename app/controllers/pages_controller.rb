class PagesController < ApplicationController
  # Só a landing é pública; abertura e instalação do app (PWA) já exigem conta.
  allow_unauthenticated_access only: :landing

  def landing
    redirect_to home_path_for(current_user) if signed_in? # a trilha leva ao passo que falta (nickname, idade, perguntas)
  end

  def intro; end

  def install; end
end
