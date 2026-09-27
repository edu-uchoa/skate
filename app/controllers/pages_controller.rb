class PagesController < ApplicationController
  # Só a landing é pública; abertura e instalação (PWA) já exigem conta.
  allow_unauthenticated_access only: :landing

  def landing
    redirect_to track_path if current_user&.onboarded?
  end

  def intro; end

  def install; end
end
