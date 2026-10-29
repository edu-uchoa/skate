require "test_helper"

# Recompressão dos vídeos para 720p em segundo plano (TranscodeClipJob + ClipTranscoder).
class TranscodeClipJobTest < ActiveJob::TestCase
  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)
    @user = User.register(contact: "rec@example.com", password: "manobra123", password_confirmation: "manobra123")
  end

  # Vídeo de teste gerado pelo ffmpeg (imagem e som sintéticos).
  def generated_video(width, height, seconds: 2)
    file = Tempfile.new([ "gerado", ".mp4" ], binmode: true)
    system(ClipTranscoder.ffmpeg, "-v", "error", "-y",
           "-f", "lavfi", "-i", "testsrc2=size=#{width}x#{height}:rate=60:duration=#{seconds}",
           "-f", "lavfi", "-i", "sine=frequency=440:duration=#{seconds}",
           "-c:v", "libx264", "-b:v", "12M", "-c:a", "aac", "-shortest", file.path, exception: true)
    file
  end

  def session_with(file)
    session = @user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :in_progress,
                                          gear_checked: true, ground_clear: true, space_safe: true)
    File.open(file.path, "rb") do |io|
      session.clip.attach(io: io, filename: "manobra.mp4", content_type: "video/mp4")
      session.clip.blob.custom_metadata = { "duration_seconds" => 2.0, "source" => "upload" }
      session.save!
    end
    file.close
    session
  end

  def dimensions(blob)
    blob.open do |file|
      probe = JSON.parse(IO.popen([ ClipTranscoder.ffprobe, "-v", "error", "-select_streams", "v:0",
                                    "-show_entries", "stream=width,height,avg_frame_rate", "-of", "json", file.path ], &:read))
      probe["streams"].first.values_at("width", "height", "avg_frame_rate")
    end
  end

  test "vídeo de 1080p deitado vira 1280x720 a 30 quadros, em MP4, com as informações do envio" do
    session = nil
    assert_enqueued_with(job: TranscodeClipJob) { session = session_with(generated_video(1920, 1080)) }

    TranscodeClipJob.perform_now(session)
    blob = session.reload.clip.blob

    assert_equal [ 1280, 720, "30/1" ], dimensions(blob)
    assert_equal "video/mp4", blob.content_type
    assert_equal({ "duration_seconds" => 2.0, "source" => "upload", "transcoded" => true }, blob.custom_metadata)
  end

  test "vídeo em pé continua em pé: 720x1280" do
    session = session_with(generated_video(1080, 1920))
    TranscodeClipJob.perform_now(session)
    width, height, = dimensions(session.reload.clip.blob)
    assert_equal [ 720, 1280 ], [ width, height ]
  end

  test "vídeo que já é pequeno fica como está, só marcado" do
    session = session_with(File.open(file_fixture("manobra.mp4")))
    blob = session.clip.blob

    TranscodeClipJob.perform_now(session)
    assert_equal blob, session.reload.clip.blob
    assert blob.reload.custom_metadata["transcoded"]
  end

  test "vídeo cortado depois do começo é recomprimido mesmo pequeno (somem os quadros escondidos)" do
    session = session_with(File.open(file_fixture("manobra.mp4")))
    blob = session.clip.blob
    blob.update!(custom_metadata: blob.custom_metadata.merge("cut_from_seconds" => 0.4))

    TranscodeClipJob.perform_now(session)
    assert_not_equal blob, session.reload.clip.blob
    assert_equal 0.4, session.clip.blob.custom_metadata["cut_from_seconds"]
    assert session.clip.blob.custom_metadata["transcoded"]
  end

  test "o ffmpeg usa uma thread só para ler e para gravar (cabe nos 512 MB do Render)" do
    command = ClipTranscoder.new("entrada.mp4").command("saida.mp4")

    assert_equal 2, command.each_cons(2).count { it == %w[-threads 1] }
    assert_operator command.index("-threads"), :<, command.index("-i"), "vale também para ler o vídeo"
  end

  test "uma conversão por vez, de qualquer vídeo, com prazo maior que o do ffmpeg" do
    first, second = 2.times.map { @user.training_sessions.create!(maneuver: @maneuver, scheduled_on: Date.current) }

    assert_equal 1, TranscodeClipJob.concurrency_limit
    assert_equal TranscodeClipJob.new(first).concurrency_key, TranscodeClipJob.new(second).concurrency_key
    assert_operator TranscodeClipJob.concurrency_duration, :>, ClipTranscoder::TIMEOUT.seconds
  end

  test "vídeo apagado antes da recompressão não volta" do
    session = session_with(generated_video(1920, 1080))
    session.remove_clip!

    TranscodeClipJob.perform_now(session)
    assert_not session.reload.clip.attached?
  end
end
