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
    # O Android pede os tamanhos 192 e 512 para oferecer a instalação.
    assert_equal %w[192x192 512x512], manifest["icons"].map { |icon| icon["sizes"] }.uniq.sort
    assert_equal "standalone", manifest["display"]
    assert_equal "pt-BR", manifest["lang"]
  end

  test "segurar o ícone do app mostra atalhos para a Trilha, o Gravar e os Picos" do
    get pwa_manifest_path(format: :json)

    shortcuts = JSON.parse(response.body)["shortcuts"].map { |shortcut| shortcut["url"] }
    assert_equal [ track_path, new_recording_path, spots_path ], shortcuts
  end

  test "o service worker guarda só o visual do app e mostra a página Sem sinal" do
    get "/service-worker.js"

    assert_response :success
    assert_includes response.media_type, "javascript"
    assert_includes response.body, %(const OFFLINE_URL = "/offline.html")
    assert_includes response.body, %(url.pathname.startsWith("/assets/")) # só /assets vai para o cache
    assert_equal 1, response.body.scan("cache.put(").size, "páginas (com dados pessoais) nunca são guardadas"
    assert Rails.public_path.join("offline.html").exist?
  end

  IPHONE_IOS_16_4 = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
                    "Version/16.4 Mobile/15E148 Safari/604.1".freeze
  IPHONE_IOS_15   = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
                    "Version/15.8 Mobile/15E148 Safari/604.1".freeze
  ANDROID_CHROME  = "Mozilla/5.0 (Linux; Android 13; SM-A135M) AppleWebKit/537.36 (KHTML, like Gecko) " \
                    "Chrome/115.0.0.0 Mobile Safari/537.36".freeze
  SAMSUNG         = "Mozilla/5.0 (Linux; Android 13; SAMSUNG SM-A536E) AppleWebKit/537.36 (KHTML, like Gecko) " \
                    "SamsungBrowser/23.0 Chrome/115.0.0.0 Mobile Safari/537.36".freeze

  test "abre em iPhone com iOS 16.4 ou mais novo e nos Androids com Chrome atualizado" do
    [ IPHONE_IOS_16_4, ANDROID_CHROME, SAMSUNG ].each do |agent|
      get root_path, headers: { "User-Agent" => agent }
      assert_response :success, agent
    end
  end

  test "celular antigo demais vê em português como atualizar" do
    get root_path, headers: { "User-Agent" => IPHONE_IOS_15 }

    assert_response :not_acceptable
    assert_includes response.body, "Seu navegador está desatualizado"
    assert_includes response.body, "iOS 16.4"
  end

  test "as páginas apontam para o ícone da aba e o da tela de início do iPhone" do
    get root_path

    assert_select "link[rel=icon][href=?]", "/icon.png"
    assert_select "link[rel=apple-touch-icon][href=?]", "/apple-touch-icon.png"
    assert Rails.public_path.join("apple-touch-icon.png").exist?
  end
end
