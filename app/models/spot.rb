# Pico fixo do mapa (config/picos.yml): fica sempre marcado, para todo mundo.
# Não fica no banco: a lista é curta e quem cuida dela edita o arquivo.
Spot = Data.define(:name, :kind, :description, :latitude, :longitude) do
  def self.file = Rails.configuration.x.flipaai.spots_file

  # Em desenvolvimento relê o arquivo a cada página, para ver a mudança na hora.
  def self.all
    @all = nil if Rails.env.local?
    @all ||= from_file(file)
  end

  def self.from_file(path)
    Array((YAML.safe_load_file(path) || {})["picos"]).map do |pico|
      new(name: pico["nome"].to_s.strip, kind: pico["tipo"].to_s.strip, description: pico["descricao"].to_s.strip,
          latitude: pico["lat"], longitude: pico["lng"])
    end.freeze
  end

  def as_json(*) = { name:, kind:, description:, lat: latitude.to_f, lng: longitude.to_f }
end
