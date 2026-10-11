# Link que a pessoa manda para os amigos (/role/:token). Abre sem login e mostra
# só o lugar, o dia, o horário e o recado: nunca quem marcou. Depois do horário
# de fim, ou se o rolê for cancelado, o link para de funcionar.
class SharedMeetupsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 60, within: 1.minute

  def show
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    response.headers["Cache-Control"] = "private, no-store"
    @meetup = Meetup.active.find_by(share_token: params[:token].to_s)
    render :expired, status: :not_found unless @meetup
  end
end
