# Tela "Minha conta" e logout. Contas novas só nascem pelo Google, na tela da logo
# (GoogleSessionsController): o e-mail já vem confirmado e ninguém cria conta com o
# e-mail de outra pessoa.
class AccountsController < ApplicationController
  # Tela "Perfil" (aba de baixo): nível, XP, ofensiva, estilo, avatar, skate e a conta.
  def show
    @stats = ProfileStats.new(current_user)
    @streak = Streak.new(current_user)
    @look  = Avatar.new(current_user.avatar_options)
    @deck  = Deck.new(current_user.board_options)
    @tab   = params[:aba] == "skate" ? "skate" : "avatar"
    load_mentor_profile if current_user.mentor_account?
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

  private

  # Conta de mentor: a média de rolamentos e as últimas avaliações dos aprendizes
  # (sem dizer quem deu, para todo mundo avaliar à vontade).
  def load_mentor_profile
    @mentor_score = MentorRating.of(current_user)
    @recent_ratings = current_user.given_reviews.rated.order(rated_at: :desc).limit(5)
  end
end
