class PagesController < ApplicationController
  # Públicas: a landing e os textos da LGPD (Política de Privacidade e Termos de Uso,
  # que a pessoa precisa poder ler antes de entrar). Abertura e instalação exigem conta.
  allow_unauthenticated_access only: %i[landing privacy terms]

  def landing
    redirect_to home_path_for(current_user) if signed_in? # a trilha leva ao passo que falta (nickname, idade, perguntas)
  end

  def intro; end

  def install; end

  def privacy; end

  def terms; end
end
