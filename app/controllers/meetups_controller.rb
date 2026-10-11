# Marcar e cancelar rolês no mapa de Picos (só os da própria pessoa).
class MeetupsController < SpotsController
  rate_limit to: 20, within: 1.hour, only: :create

  def create
    @meetup = current_user.meetups.new(meetup_params)

    if @meetup.save
      redirect_to spots_path(anchor: "meetup_#{@meetup.id}"), notice: "Rolê marcado! Agora é só chamar a galera."
    else
      load_map
      render "spots/index", status: :unprocessable_entity
    end
  end

  def destroy
    current_user.meetups.find(params[:id]).destroy!
    redirect_to spots_path, notice: "Rolê cancelado. O link que você mandou parou de funcionar."
  end

  private

  def meetup_params
    params.require(:meetup).permit(:place_name, :latitude, :longitude, :day, :start_time, :end_time, :note)
  end
end
