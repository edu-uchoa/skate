# Cadastro (com a conta Google), tela "Minha conta" e logout. Contas novas só nascem
# pelo Google (GoogleSessionsController): o e-mail já vem confirmado e ninguém cria
# conta com o e-mail de outra pessoa.
class AccountsController < ApplicationController
  allow_unauthenticated_access only: :new
  require_no_authentication only: :new

  def new; end

  # Tela "Perfil" (aba de baixo): nível, XP, ofensiva, estilo, avatar, skate e a conta.
  def show
    @stats = ProfileStats.new(current_user)
    @streak = Streak.new(current_user)
    @look  = Avatar.new(current_user.avatar_options)
    @deck  = Deck.new(current_user.board_options)
    @tab   = params[:aba] == "skate" ? "skate" : "avatar"
  end

  def destroy
    sign_out
    redirect_to root_path, notice: "Sessão encerrada neste aparelho."
  end

  def destroy_all
    current_user.sign_out_everywhere!
    sign_out
    redirect_to root_path, notice: "Sessão encerrada em todos os aparelhos."
  end
end
