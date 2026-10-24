require "test_helper"

# Depois de sair, o "voltar" do navegador não pode mostrar as telas da conta (num
# celular emprestado, outra pessoa veria o chat e o Perfil). As telas de quem está
# logado não ficam guardadas (Cache-Control: no-store) e, sem conta, o application.js
# apaga as cópias do Turbo (body[data-signed-in=false]).
class PrivateCacheTest < ActionDispatch::IntegrationTest
  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                     position: 0, kind: :drill, description: "Monte o seu skate.")
    @user = sign_up_with_google("guardado@example.com")
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    @user.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
  end

  test "telas de quem está logado não ficam guardadas no navegador" do
    [ track_path, my_account_path, chat_path ].each do |path|
      get path
      assert_response :success
      assert_includes response.headers["Cache-Control"], "no-store", path
      assert_select "body[data-signed-in=true]"
    end
  end

  test "depois de sair, a tela avisa o app para apagar as cópias e a conta não abre mais" do
    delete sign_out_path
    follow_redirect!
    assert_select "body[data-signed-in=false]"
    assert_not_includes response.headers["Cache-Control"].to_s, "no-store", "a logo pode ficar guardada"

    get chat_path
    assert_redirected_to root_path
  end
end
