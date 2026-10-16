module Admin
  # Base do painel do super administrador (/painel). Exige login (padrão do app) e a
  # conta de super admin (User#super_admin?). Para os demais responde 404, sem revelar
  # que o painel existe. Toda remoção feita aqui fica registrada no log do servidor.
  class BaseController < ApplicationController
    LIMIT = 100 # itens por lista, do mais novo para o mais antigo

    before_action :require_super_admin

    private

    def require_super_admin
      return if current_user.super_admin?
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
    end

    def audit(action) = Rails.logger.warn("[FlipaAi] super admin #{current_user.id} #{action}")
  end
end
