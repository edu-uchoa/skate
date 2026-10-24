# Salva o skate do Perfil: tipo (com a estampa padrão), rodas e trucks (Deck).
class DecksController < ApplicationController
  before_action :require_onboarding

  def update
    current_user.update!(board_options: Deck.new(params.fetch(:deck, {}).permit(*Deck::DEFAULTS.keys).to_h).to_h)
    redirect_to my_account_path(aba: "skate", anchor: "personalizar"), notice: "Skate salvo!"
  end
end
