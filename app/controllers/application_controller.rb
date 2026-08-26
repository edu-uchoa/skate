class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  private

  # Progresso do usuário na trilha, memoizado por requisição.
  def progression
    @progression ||= TrackProgression.new(current_user)
  end
  helper_method :progression
end
