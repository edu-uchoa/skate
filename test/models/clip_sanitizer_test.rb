require "test_helper"

class ClipSanitizerTest < ActiveSupport::TestCase
  def clean(name, content_type)
    ClipSanitizer.new({ io: File.open(file_fixture(name), "rb"), filename: name, content_type: content_type }).call
  end

  test "os vídeos de teste imitam celular: têm localização, data e aparelho" do
    assert_match "+38.7223", video_metadata(file_fixture("manobra.mp4"))[:tags]["location"]
    assert_equal "iPhone 15", video_metadata(file_fixture("manobra_iphone.mov"))[:tags]["com.apple.quicktime.model"]
  end

  test "tira localização, data, título e aparelho, e mantém imagem, som e vídeo em pé" do
    { "manobra.mp4" => [ "video/mp4", "video.mp4" ], "manobra_iphone.mov" => [ "video/quicktime", "video.mov" ] }.each do |name, (type, filename)|
      result = clean(name, type)
      metadata = video_metadata(result[:io].path)

      assert_equal filename, result[:filename], "o nome original do arquivo não fica"
      assert_equal type, result[:content_type]
      assert_empty metadata[:tags].keys - CLEAN_VIDEO_TAGS, "#{name} ainda tem metadados"
      assert_equal %w[video audio], metadata[:streams]
      assert_equal 90, metadata[:rotation], "#{name} perdeu a rotação"
    end
  end

  test "com um trecho, guarda só ele, ainda sem metadados e em pé" do
    result = ClipSanitizer.new({ io: File.open(file_fixture("manobra_iphone.mov"), "rb"), filename: "x.mov",
                                 content_type: "video/quicktime" }, cut: 0.4..1.0).call
    duration = IO.popen([ "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", result[:io].path ], &:read).to_f
    metadata = video_metadata(result[:io].path)

    assert_in_delta 0.6, duration, 0.05, "o vídeo de 1s começa em 0,4s"
    assert_empty metadata[:tags].keys - CLEAN_VIDEO_TAGS
    assert_equal 90, metadata[:rotation]
  end

  test "recusa o que não é vídeo, vídeo corrompido e arquivo grande demais" do
    disguised = ClipSanitizer.new({ io: File.open(file_fixture("disfarcado.mp4"), "rb"), filename: "x.mp4", content_type: "video/mp4" })
    broken    = ClipSanitizer.new({ io: StringIO.new("\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom".b), filename: "x.mp4" })
    too_big   = ClipSanitizer.new({ io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "x.mp4" }, max_bytes: 10)

    assert_equal :format,     assert_raises(ClipSanitizer::Error) { disguised.call }.reason
    assert_equal :unreadable, assert_raises(ClipSanitizer::Error) { broken.call }.reason
    assert_equal :size,       assert_raises(ClipSanitizer::Error) { too_big.call }.reason
    assert_equal :format,     assert_raises(ClipSanitizer::Error) { ClipSanitizer.new("id-de-outro-arquivo").call }.reason
  end

  test "vídeo que passa do tempo é recusado e fica no log, sem erro da leitura em outra thread" do
    logs = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logs)
    sanitizer = ClipSanitizer.new({ io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "x.mp4",
                                    content_type: "video/mp4" }, timeout: 0)

    _, errors = capture_io do
      assert_equal :unreadable, assert_raises(ClipSanitizer::Error) { sanitizer.call }.reason
      sleep 0.2 # tempo para um erro da outra thread aparecer
    end
    assert_match "[ClipSanitizer] o ffmpeg passou de 0s e foi interrompido", logs.string
    assert_no_match "IOError", errors
  ensure
    Rails.logger = original_logger
  end

  test "videos:limpar limpa os vídeos guardados antes, no mesmo lugar" do
    user = User.register(contact: "antigo@example.com", password: "manobra123", password_confirmation: "manobra123")
    maneuver = Maneuver.create!(learning_module: LearningModule.create!(code: "8", name: "T", position: 8),
                                code: "8.0", slug: "t-antigo", name: "ANTIGO", position: 0)
    training_session = user.training_sessions.create!(maneuver: maneuver, scheduled_on: Date.current)
    # Como era antes: o arquivo original, sem passar pelo ClipSanitizer.
    blob = ActiveStorage::Blob.create_and_upload!(io: File.open(file_fixture("manobra_iphone.mov"), "rb"),
                                                  filename: "IMG_0042 joao.MOV", content_type: "video/quicktime")
    ActiveStorage::Attachment.create!(record: training_session, name: "clip", blob: blob)

    Rails.application.load_tasks unless Rake::Task.task_defined?("videos:limpar")
    assert_output(/1 vídeo\(s\) limpo\(s\)/) { Rake::Task["videos:limpar"].execute }

    blob.reload
    assert_equal "video.mov", blob.filename.to_s
    assert_empty blob.open { |file| video_metadata(file.path) }[:tags].keys - CLEAN_VIDEO_TAGS
    assert_equal blob, training_session.reload.clip.blob, "o mesmo arquivo, regravado limpo"
  end

  test "sem ffmpeg nenhum vídeo entra" do
    original = Rails.configuration.x.flipaai.ffmpeg_path
    Rails.configuration.x.flipaai.ffmpeg_path = "ffmpeg-que-nao-existe"
    assert_equal :unavailable, assert_raises(ClipSanitizer::Error) { clean("manobra.mp4", "video/mp4") }.reason
  ensure
    Rails.configuration.x.flipaai.ffmpeg_path = original
  end
end
