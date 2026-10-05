module Mentor
  # Base da área do mentor: exige login (padrão do app) e conta de mentor.
  # Para quem não é mentor responde 404, sem revelar que a área existe.
  class BaseController < ApplicationController
    before_action :require_mentor

    private

    def require_mentor
      return if current_user.role_mentor?

      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
    end
  end
end
