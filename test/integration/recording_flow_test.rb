require "test_helper"

class RecordingFlowTest < ActionDispatch::IntegrationTest
  CHECKLIST = { gear_checked: "1", ground_clear: "1", space_safe: "1" }.freeze

  setup do
    learning_module = LearningModule.create!(code: "9", name: "TESTE", position: 99)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "9.0", slug: "t-ollie",
                                 name: "OLLIE", position: 0)
    @locked   = Maneuver.create!(learning_module: learning_module, code: "9.1", slug: "t-kickflip",
                                 name: "KICKFLIP", position: 1, prerequisite: @maneuver)

    post account_path, params: { user: { contact: "rec@example.com", password: "manobra123", password_confirmation: "manobra123" } }
    @user = User.last
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    @user.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
  end

  def upload(file: "manobra.mp4", type: "video/mp4", duration: "8.4", **overrides)
    clip = fixture_file_upload(file, type, true) # binário: no Windows o modo texto corta no byte 0x1A
    params = { recording: { clip: clip, maneuver_slug: @maneuver.slug, duration_seconds: duration, source: "camera", **CHECKLIST, **overrides } }
    post recording_path, params: params, headers: { "Accept" => "application/json" }
  end

  test "a página Gravar exige login" do
    delete sign_out_path
    get new_recording_path
    assert_redirected_to new_session_path
  end

  test "a página Gravar lista só manobras liberadas" do
    get new_recording_path
    assert_response :success
    assert_match "OLLIE", response.body
    assert_no_match "KICKFLIP", response.body
  end

  test "envio válido salva o vídeo com metadados e leva ao resultado" do
    assert_difference -> { @user.training_sessions.count } => 1, -> { ActiveStorage::Blob.count } => 1 do
      upload
    end
    assert_response :created

    session = @user.training_sessions.last
    assert_equal({ "redirect_url" => result_training_session_path(session) }, response.parsed_body)
    assert session.status_in_progress?
    assert_equal @maneuver, session.maneuver
    assert session.clip.attached?
    assert_equal "video/mp4", session.clip.content_type
    assert_equal({ "duration_seconds" => 8.4, "source" => "camera" }, session.clip.blob.custom_metadata)
    assert session.clip.blob.service.exist?(session.clip.blob.key), "arquivo gravado no storage"

    get result_training_session_path(session)
    assert_response :success
    assert_match "Vídeo salvo", response.body
  end

  test "enviar o resultado de um treino com vídeo cria a análise da IA" do
    upload
    session = @user.training_sessions.last

    patch submit_training_session_path(session), params: { training_session: { outcome: "felt_safe" } }
    assert session.reload.status_submitted?
    assert session.ai_review.present?
  end

  test "rejeita vídeo longo, formato inválido, sem vídeo e sem checklist" do
    assert_no_difference -> { TrainingSession.count } do
      upload(duration: "40")
      assert_response :unprocessable_entity
      assert_match "15 segundos", response.parsed_body["errors"].join

      upload(file: "disfarcado.mp4")
      assert_match "Formato de vídeo não suportado", response.parsed_body["errors"].join

      upload(gear_checked: "0")
      assert_match "checklist", response.parsed_body["errors"].join

      post recording_path, params: { recording: { maneuver_slug: @maneuver.slug, **CHECKLIST } },
                           headers: { "Accept" => "application/json" }
      assert_match "Grave ou escolha um vídeo", response.parsed_body["errors"].join
    end
  end

  test "rejeita vídeo acima do tamanho máximo" do
    original = Rails.configuration.x.sakte.max_clip_bytes
    Rails.configuration.x.sakte.max_clip_bytes = 10
    upload
    assert_response :unprocessable_entity
    assert_match "MB", response.parsed_body["errors"].join
  ensure
    Rails.configuration.x.sakte.max_clip_bytes = original
  end

  test "não aceita manobra bloqueada: cai na manobra atual" do
    upload(maneuver_slug: @locked.slug)
    assert_equal @maneuver, @user.training_sessions.last.maneuver
  end
end
