require "test_helper"

class RecordingFlowTest < ActionDispatch::IntegrationTest
  CHECKLIST = { gear_checked: "1", ground_clear: "1", space_safe: "1" }.freeze

  setup do
    learning_module = LearningModule.create!(code: "9", name: "TESTE", position: 99)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "9.0", slug: "t-ollie",
                                 name: "OLLIE", position: 0)
    @locked   = Maneuver.create!(learning_module: learning_module, code: "9.1", slug: "t-kickflip",
                                 name: "KICKFLIP", position: 1, prerequisite: @maneuver)

    sign_up_with_google("rec@example.com")
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
    assert_redirected_to root_path
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

  test "o vídeo do iPhone é guardado sem localização, data, aparelho nem o nome do arquivo" do
    upload(file: "manobra_iphone.mov", type: "video/quicktime")
    assert_response :created

    blob = @user.training_sessions.last.clip.blob
    assert_equal "video.mov", blob.filename.to_s
    assert_equal "video/quicktime", blob.content_type
    metadata = blob.open { |file| video_metadata(file.path) }
    assert_empty metadata[:tags].keys - CLEAN_VIDEO_TAGS
    assert_equal 90, metadata[:rotation]
  end

  test "o vídeo enviado na tela de resultado também é limpo" do
    session = @user.training_sessions.create!(maneuver: @maneuver, scheduled_on: Date.current, status: :in_progress, **CHECKLIST)
    patch submit_training_session_path(session),
          params: { training_session: { outcome: "felt_safe", clip: fixture_file_upload("manobra.mp4", "video/mp4", true) } }

    blob = session.reload.clip.blob
    assert_equal "video.mp4", blob.filename.to_s
    assert_empty blob.open { |file| video_metadata(file.path) }[:tags].keys - CLEAN_VIDEO_TAGS
  end

  test "sem ffmpeg o vídeo é recusado e nada é guardado" do
    original = Rails.configuration.x.flipaai.ffmpeg_path
    Rails.configuration.x.flipaai.ffmpeg_path = "ffmpeg-que-nao-existe"

    assert_no_difference -> { ActiveStorage::Blob.count } do
      upload
    end
    assert_response :unprocessable_entity
    assert_equal [ "Não conseguimos proteger este vídeo agora. Tente de novo em alguns minutos." ], response.parsed_body["errors"]
  ensure
    Rails.configuration.x.flipaai.ffmpeg_path = original
  end

  test "enviar o resultado de um treino com vídeo coloca o vídeo na fila do mentor" do
    upload
    session = @user.training_sessions.last

    assert_no_enqueued_jobs(only: AnalyzeTrainingSessionJob) do
      patch submit_training_session_path(session), params: { training_session: { outcome: "felt_safe" } }
    end
    assert session.reload.status_submitted?
    assert session.ai_review.status_pending?, "sem análise automática, a devolutiva fica esperando o mentor"
    assert_nil session.ai_review.headline

    follow_redirect!
    assert_select ".screen-title", /fila do mentor/
    assert_match "48 horas", response.body
    assert_no_match(/Scanner|Análise da IA/i, response.body)
  end

  test "a análise automática ligada antes de existir recusa inventar uma devolutiva" do
    upload
    session = @user.training_sessions.last
    Rails.configuration.x.flipaai.automatic_review = true

    assert_enqueued_jobs 1, only: AnalyzeTrainingSessionJob do
      patch submit_training_session_path(session), params: { training_session: { outcome: "felt_safe" } }
    end
    assert_raises(Ai::FallAnalyzer::NotConfigured) { perform_enqueued_jobs }
    assert session.reload.ai_review.status_failed?
  ensure
    Rails.configuration.x.flipaai.automatic_review = false
  end

  test "a câmera do app tem o botão de trocar entre traseira e frontal" do
    get new_recording_path
    assert_select "[data-recorder-target=camera]" do
      assert_select "button.rec-switch-btn[data-action='recorder#switchCamera'][hidden][aria-label]" # aparece só com 2 câmeras
      assert_select "[data-recorder-target=notice][hidden]"
    end
  end

  # Vídeo de teste com a duração pedida (imagem pequena e som sintéticos, gerados pelo ffmpeg).
  def long_video(seconds)
    file = Tempfile.new([ "longo", ".mp4" ], binmode: true)
    file.close
    system(ClipSanitizer.ffmpeg, "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=size=96x64:rate=10:duration=#{seconds}",
           "-f", "lavfi", "-i", "sine=duration=#{seconds}", "-c:v", "libx264", "-g", "10", "-c:a", "aac", "-shortest",
           file.path, exception: true)
    Rack::Test::UploadedFile.new(file.path, "video/mp4", true)
  end

  # O corte sem recomprimir acerta o começo, mas pode passar uns quadros no fim
  # (a ordem dos quadros do H.264): até meio segundo a mais.
  def assert_stored_seconds(expected, training_session)
    seconds = training_session.clip.blob.open do |file|
      IO.popen([ "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file.path ], &:read).to_f
    end
    assert_includes (expected - 0.05)..(expected + 0.5), seconds, "o vídeo guardado tem #{seconds}s"
  end

  def post_long_video(seconds, **fields)
    post recording_path, headers: { "Accept" => "application/json" },
                         params: { recording: { clip: long_video(seconds), maneuver_slug: @maneuver.slug, source: "camera", **CHECKLIST, **fields } }
  end

  test "a tela Gravar tem a barra de corte de até 20s, com as orientações" do
    get new_recording_path
    assert_select "[data-recorder-clip-trim-outlet='#rec-preview']"
    assert_select "#rec-preview[data-controller=clip-trim][data-clip-trim-max-seconds-value='20']" do
      assert_select "video[data-clip-trim-target=video][controls][playsinline]" # sem a barra, ainda dá para assistir
      assert_select ".rec-trim[hidden] .rec-trim-handle[role=slider][tabindex='0']", 2
      assert_select ".rec-trim-tips li", 3
      assert_select "input[type=hidden][name='recording[cut_from]']"
      assert_select "input[type=hidden][name='recording[cut_to]']"
      assert_select "input[type=hidden][name='recording[duration_seconds]']"
    end
    assert_match "Arraste as bordas amarelas até o começo e o fim da sua tentativa.", response.body
    assert_match "Depois você corta só o trecho da tentativa, com até 20 segundos.", response.body
    assert_no_match "Tente não enviar", response.body
  end

  test "só o trecho escolhido na barra de corte é guardado" do
    assert_enqueued_with(job: TranscodeClipJob) do
      post_long_video(30, duration_seconds: "30", cut_from: "5.5", cut_to: "15.5")
    end
    assert_response :created

    session = TrainingSession.last
    assert_stored_seconds 10, session
    assert_equal({ "duration_seconds" => 10.0, "cut_from_seconds" => 5.5, "source" => "camera" }, session.clip.blob.custom_metadata)
  end

  test "sem trecho escolhido, ou com um trecho maior que 20s, ficam só 20 segundos" do
    post_long_video(30, duration_seconds: "30")
    assert_stored_seconds 20, TrainingSession.last
    assert_equal 20.0, TrainingSession.last.clip_duration

    post_long_video(30, duration_seconds: "30", cut_from: "2", cut_to: "29") # trecho forjado fora da tela
    assert_stored_seconds 20, TrainingSession.last
    assert_equal 2.0, TrainingSession.last.clip.blob.custom_metadata["cut_from_seconds"]
  end

  test "rejeita formato inválido, sem vídeo e sem checklist" do
    assert_no_difference -> { TrainingSession.count } do
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
    original = Rails.configuration.x.flipaai.max_clip_bytes
    Rails.configuration.x.flipaai.max_clip_bytes = 10
    upload
    assert_response :unprocessable_entity
    assert_match "MB", response.parsed_body["errors"].join
  ensure
    Rails.configuration.x.flipaai.max_clip_bytes = original
  end

  test "não aceita manobra bloqueada: cai na manobra atual" do
    upload(maneuver_slug: @locked.slug)
    assert_equal @maneuver, @user.training_sessions.last.maneuver
  end
end
