# Ajuda mínima: três portas (machucou / travou / bug), tudo cai no WhatsApp.
class SupportRequestsController < ApplicationController
  def new
    @support_request = current_user.support_requests.build(kind: params[:kind])
    @maneuver = Maneuver.find_by(slug: params[:maneuver_slug])
  end

  def create
    @support_request = current_user.support_requests.build(support_request_params)

    if @support_request.save
      redirect_to @support_request.whatsapp_url, allow_other_host: true
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def support_request_params
    params.require(:support_request).permit(:kind, :message, :contact, :maneuver_id)
  end
end
