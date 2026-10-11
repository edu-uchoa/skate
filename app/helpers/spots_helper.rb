module SpotsHelper
  SPOT_ICONS = { "rua" => "location_city", "pista" => "skateboarding", "praça" => "park", "praca" => "park" }.freeze

  # Dados que o spots_map_controller.js usa para montar o mapa do Google.
  def spots_map_data(spots, meetups)
    config = Rails.configuration.x.stance
    {
      controller: "spots-map",
      spots_map_api_key_value: config.google_maps_key.to_s,
      spots_map_map_id_value: config.google_maps_map_id.to_s,
      spots_map_center_value: config.map_center.to_json,
      spots_map_spots_value: spots.to_json,
      spots_map_meetups_value: meetups.map { |meetup| { id: meetup.id, lat: meetup.latitude.to_f, lng: meetup.longitude.to_f } }.to_json
    }
  end

  # Ícone do tipo de pico (o bowl tem desenho próprio: o Material Symbols não tem).
  def spot_icon(spot)
    return render("shared/icon_bowl") if spot.kind.downcase == "bowl"

    tag.span(SPOT_ICONS.fetch(spot.kind.downcase, "place"), class: "material-symbols-outlined")
  end

  # Mensagem que vai junto com o link: o lugar e o horário, sem dizer quem marcou.
  def meetup_share_text(meetup) = "Bora andar de skate? #{meetup.place_name} · #{meetup.schedule_label}."
end
