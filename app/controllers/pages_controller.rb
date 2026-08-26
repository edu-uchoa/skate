class PagesController < ApplicationController
  # Telas públicas: landing, abertura e instruções de instalação (PWA).
  def landing
    redirect_to track_path if current_user.onboarded?
  end

  def intro; end

  def install; end
end
