class ApplicationController < ActionController::Base
  include Authentication

  # O mínimo de que o app precisa (CSS do Tailwind 4 e o import map do JavaScript):
  # iPhone com iOS 16.4+ e Chrome 111+ no Android. O :modern pedia iOS 17.2 e
  # Chrome 120, e barrava muitos celulares que rodam o app sem problema.
  # Navegadores não listados (Samsung Internet, Edge...) e apps que não dizem a
  # versão passam. Quem fica de fora vê public/406-unsupported-browser.html.
  MINIMUM_BROWSERS = { safari: 16.4, chrome: 111, firefox: 128, opera: 97, ie: false }.freeze
  allow_browser versions: MINIMUM_BROWSERS

  private

  # Progresso do usuário na trilha, memoizado por requisição.
  def progression
    @progression ||= TrackProgression.new(current_user)
  end
  helper_method :progression
end
