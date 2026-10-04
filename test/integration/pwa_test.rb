require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "o manifesto instala o app com o nome e os ícones da Stance" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal "Stance", manifest["name"]
    assert_equal "Stance", manifest["short_name"]
    assert manifest["icons"].any? { |icon| icon["purpose"] == "maskable" }, "precisa de um ícone maskable (Android)"
    manifest["icons"].each do |icon|
      assert Rails.public_path.join(icon["src"].delete_prefix("/")).exist?, "ícone #{icon["src"]} não existe em public/"
    end
  end

  test "as páginas apontam para o ícone da aba e o da tela de início do iPhone" do
    get root_path

    assert_select "link[rel=icon][href=?]", "/icon.png"
    assert_select "link[rel=apple-touch-icon][href=?]", "/apple-touch-icon.png"
    assert Rails.public_path.join("apple-touch-icon.png").exist?
  end
end
