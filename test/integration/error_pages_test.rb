require "test_helper"

# Páginas de erro (public/400, 404, 422 e 500): em português e no visual do app, com o
# caminho de volta. Eram as padrão do Rails, brancas e em inglês.
class ErrorPagesTest < ActionDispatch::IntegrationTest
  test "as páginas de erro estão em português, com o botão de volta para o app" do
    %w[400 404 422 500].each do |code|
      page = Rails.public_path.join("#{code}.html").read
      assert_includes page, '<html lang="pt-BR">', code
      assert_includes page, '<a href="/">Voltar para o FlipaAi</a>', code
      assert_no_match(/application owner|doesn't exist|went wrong/, page, code)
    end
  end

  test "aprendiz que abre a área do mentor vê a página de não encontrada em português" do
    sign_up_with_google("curioso@example.com")
    get mentor_zine_path
    assert_response :not_found
    assert_match "Não achamos esta página", response.body
  end
end
