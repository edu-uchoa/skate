# Aba "Picos": mapa do Google Maps com os picos fixos (config/picos.yml) e os
# rolês que a pessoa marcou. Só funciona com a localização do aparelho liberada
# (spots_map_controller.js); a localização só centraliza o mapa no navegador e
# nunca é enviada ao servidor.
class SpotsController < ApplicationController
  before_action :redirect_mentor_account
  def index
    Meetup.purge_expired!
    @meetup = suggested_meetup
    load_map
  end

  private

  # Usado também pelo MeetupsController para redesenhar a página com os erros.
  def load_map
    @meetups = current_user.meetups.upcoming
    @spots   = Spot.all
  end

  # Formulário já preenchido com a próxima hora cheia, por 2 horas. Depois das 21h,
  # sugere o dia seguinte às 16h.
  def suggested_meetup
    now   = Time.current.in_time_zone(current_user.time_zone)
    start = now.beginning_of_hour + 1.hour
    start = now.tomorrow.change(hour: 16) if start.hour >= 22 || start.to_date != now.to_date

    current_user.meetups.new(day: start.to_date, start_time: start.strftime("%H:%M"),
                             end_time: (start + 2.hours).strftime("%H:%M"))
  end
end
