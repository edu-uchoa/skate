# "Verificação por código": confirma o código de 6 dígitos e salva o perfil.
class AccessCodesController < ApplicationController
  before_action :set_access_code, only: %i[create]

  def new
    @access_code = current_user.access_codes.usable.order(:created_at).last
    redirect_to new_account_path if @access_code.blank?
  end

  def create
    if @access_code.blank?
      return redirect_to new_account_path, alert: "Código expirado. Peça um novo."
    end

    if @access_code.verify(params[:code])
      current_user.register!(@access_code.destination)
      redirect_to track_path, notice: "Progresso salvo com segurança."
    else
      flash.now[:alert] = "Código inválido ou expirado."
      render :new, status: :unprocessable_entity
    end
  end

  def resend
    latest = current_user.access_codes.order(:created_at).last
    return redirect_to new_account_path if latest.blank?

    code = AccessCode.issue!(user: current_user, destination: latest.destination)
    AccessCodeDelivery.new(code).call
    redirect_to new_access_code_path, notice: "Novo código enviado."
  end

  private

  def set_access_code
    @access_code = current_user.access_codes.usable.order(:created_at).last
  end
end
