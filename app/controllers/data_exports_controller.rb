# "Meus dados" no Perfil: baixa um arquivo JSON com tudo o que o FlipaAi guarda sobre
# a pessoa (DataExport). Só da própria conta, sempre logado.
class DataExportsController < ApplicationController
  rate_limit to: 5, within: 1.minute

  def show
    export = DataExport.new(current_user, clip_url: ->(session) { clip_url(session) })
    send_data export.to_json, filename: export.filename, type: "application/json", disposition: "attachment"
  end
end
