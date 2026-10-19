require "test_helper"

# Envio do vídeo pela fila do aparelho: a tela Gravar guarda o vídeo (criptografado, no
# celular) e a tela de envio manda com o anel de progresso. O servidor só vê o envio de
# sempre (POST /gravar com login, token CSRF e o vídeo limpo pelo ClipSanitizer).
class UploadQueueTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP", position: 0, kind: :drill,
                     description: "Monte o seu skate.")
    @learner = account("aprendiz@example.com")
    @other   = account("outra@example.com")
  end

  def account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 2000, terms_accepted_at: Time.current)
      user.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
    end
  end

  def sign_in(user) = post(session_path, params: { session: { contact: user.contact, password: PASSWORD } })
  def owner_key = css_select("[data-upload-sender-owner-value]").first["data-upload-sender-owner-value"]

  test "a tela Gravar já traz a tela de envio escondida, com o anel e a conta do aparelho" do
    sign_in(@learner)
    get new_recording_path

    assert_select ".rec-screen[data-recorder-owner-value]"
    assert_select ".send-screen[hidden][data-upload-sender-autostart-value=false]" do
      assert_select ".send-ring svg circle.send-ring-fill[pathLength='100']"
      assert_select "[data-upload-sender-target=title]"
    end
    assert_equal css_select(".rec-screen").first["data-recorder-owner-value"], owner_key
    assert_select "[data-upload-sender-url-value=?]", recording_path
  end

  test "a página de envio abre sozinha e cada conta tem a sua chave, sem mostrar quem é" do
    sign_in(@learner)
    get sending_recording_path
    assert_response :success
    assert_select ".send-screen:not([hidden])[data-upload-sender-autostart-value=true]"
    key = owner_key
    assert_match(/\A\h{32}\z/, key)
    delete sign_out_path

    sign_in(@other)
    get sending_recording_path
    assert_not_equal key, owner_key, "outra conta no mesmo celular não pega o vídeo"
  end

  test "o aviso do topo existe para o aprendiz (escondido até ter vídeo guardado) e não para o mentor" do
    sign_in(@learner)
    get track_path
    assert_select "a.pending-upload[hidden][href=?][data-controller=pending-upload]", sending_recording_path
    delete sign_out_path

    mentor = account("mentor@example.com").tap(&:role_mentor!)
    sign_in(mentor)
    get my_account_path
    assert_select "a.pending-upload", 0
    get sending_recording_path
    assert_redirected_to mentor_zine_path
  end

  test "apagar a conta também limpa a fila do aparelho" do
    sign_in(@learner)
    get account_deletion_path
    assert_select "form[data-controller=pending-upload][data-action*='pending-upload#clearAll']"
  end
end
