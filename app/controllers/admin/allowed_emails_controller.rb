module Admin
  # Lista de acesso (AllowedEmail): os e-mails que podem usar o app publicado. O super
  # admin libera e tira. Tirar corta o acesso na hora, mas a conta e os dados continuam.
  class AllowedEmailsController < BaseController
    def index
      @allowed_email = AllowedEmail.new
      load_list
    end

    def create
      @allowed_email = AllowedEmail.new(params.require(:allowed_email).permit(:email))
      if @allowed_email.save
        audit("liberou o acesso de #{@allowed_email.email}")
        redirect_to admin_allowed_emails_path, notice: "#{@allowed_email.email} já pode entrar no app."
      else
        load_list
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      allowed_email = AllowedEmail.find(params[:id])
      allowed_email.destroy!
      audit("tirou o acesso de #{allowed_email.email}")
      redirect_to admin_allowed_emails_path, notice: "#{allowed_email.email} não entra mais no app. A conta e os dados continuam."
    end

    private

    def load_list
      @allowed_emails = AllowedEmail.order(:email)
      @accounts = User.registered.where(email: @allowed_emails.map(&:email)).index_by(&:email)
    end
  end
end
