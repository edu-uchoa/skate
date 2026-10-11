require "test_helper"

class SpotTest < ActiveSupport::TestCase
  # Protege quem edita config/picos.yml: cada pico precisa de nome e de coordenadas no Brasil.
  test "os picos de config/picos.yml estão preenchidos certo" do
    assert_kind_of Array, Spot.all
    Spot.all.each do |spot|
      assert spot.name.present?, "pico sem nome em config/picos.yml"
      assert_kind_of Numeric, spot.latitude, "#{spot.name}: lat precisa ser um número (ex.: -15.7939)"
      assert_kind_of Numeric, spot.longitude, "#{spot.name}: lng precisa ser um número (ex.: -47.8828)"
      assert spot.latitude.between?(-34, 6) && spot.longitude.between?(-74, -34),
             "#{spot.name}: as coordenadas não caem no Brasil (troque lat e lng de lugar?)"
    end
  end

  test "lê nome, tipo, descrição e coordenadas do arquivo" do
    file = Tempfile.new([ "picos", ".yml" ])
    file.write({ "picos" => [ { "nome" => " Pista teste ", "tipo" => "pista", "descricao" => "Piso liso.",
                                "lat" => -15.7939, "lng" => -47.8828 } ] }.to_yaml)
    file.close

    spot = Spot.from_file(file.path).sole
    assert_equal "Pista teste", spot.name
    assert_equal({ name: "Pista teste", kind: "pista", description: "Piso liso.", lat: -15.7939, lng: -47.8828 }, spot.as_json)
  ensure
    file&.unlink
  end
end
