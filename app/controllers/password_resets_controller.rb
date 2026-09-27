# "Esqueci minha senha": envia um código de acesso ao e-mail/WhatsApp da conta
# e, com o código certo, deixa criar uma senha nova.
class PasswordResetsController < ApplicationController
  allow_unauthenticated_access
  require_no_authentication

  rate_limit to: 10, within: 3.minutes, only: %i[create update resend],
             with: -> { redirect_to new_password_reset_path, alert: "Muitas tentativas. Aguarde alguns minutos." }

  before_action :set_user, only: %i[edit update resend]

  def new; end

  def create
    contact = params.dig(:password_reset, :contact).to_s.strip

    unless User.valid_contact?(contact)
      flash.now[:alert] = "Informe um e-mail ou telefone válido."
      return render :new, status: :unprocessable_entity
    end

    session[:password_reset_contact] = User.normalize_contact(contact)
    user = User.find_registered_by_contact(contact)
    deliver_code_to(user) if user

    # Mesma resposta com ou sem conta: não revela quem está cadastrado.
    redirect_to edit_password_reset_path, notice: "Se houver uma conta com esse contato, enviamos um código."
  end

  def edit; end

  def update
    password, confirmation = params[:password].to_s, params[:password_confirmation].to_s

    # A senha é conferida antes do código, para um erro de digitação não gastar o código.
    if (problem = User.password_problem(password, confirmation))
      flash.now[:alert] = problem
      return render :edit, status: :unprocessable_entity
    end

    access_code = @user&.access_codes&.usable&.order(:created_at)&.last
    unless access_code&.verify(params[:code])
      flash.now[:alert] = "Código inválido ou expirado."
      return render :edit, status: :unprocessable_entity
    end

    @user.update!(password: password, password_confirmation: confirmation)
    @user.sign_out_everywhere!
    session.delete(:password_reset_contact)
    start_session_for(@user)
    redirect_to track_path, notice: "Senha atualizada. Você já está dentro!"
  end

  def resend
    deliver_code_to(@user) if @user
    redirect_to edit_password_reset_path, notice: "Se houver uma conta com esse contato, enviamos um novo código."
  end

  private

  def set_user
    @contact = session[:password_reset_contact]
    return redirect_to new_password_reset_path if @contact.blank?
    @user = User.find_registered_by_contact(@contact)
  end

  def deliver_code_to(user)
    access_code = AccessCode.issue!(user: user, destination: user.contact)
    AccessCodeDelivery.new(access_code).call
  end
end
