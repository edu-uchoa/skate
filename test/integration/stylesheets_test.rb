require "test_helper"

# Os estilos do app vêm uma vez só, depois do Tailwind. Antes, o custom_styles vinha duas
# vezes e o @import do application.css pedia /assets/custom_styles.css (404 em toda página).
class StylesheetsTest < ActionDispatch::IntegrationTest
  test "cada estilo é carregado uma vez, com os do app por último" do
    get root_path
    links = css_select("link[rel=stylesheet]").map { it["href"] }
    assert_equal 1, links.count { it.include?("/custom_styles-") }
    assert_match %r{/custom_styles-}, links.last, "os estilos do app vencem o Tailwind"
    assert_operator links.index { it.include?("/tailwind-") }, :<, links.size - 1
  end

  test "o application.css não importa outro arquivo" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_no_match(/^\s*@import/, css)
  end
end
