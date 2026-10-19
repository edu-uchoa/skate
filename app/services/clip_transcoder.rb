# Recomprime o vídeo do treino para 720p (no máximo 30 quadros por segundo), em MP4
# (H.264 + AAC), que toca em qualquer celular. Um vídeo de 1080p do celular cai para
# cerca de um terço do tamanho, sem perder o que o mentor precisa ver.
#
# Roda em segundo plano (TranscodeClipJob), depois que o vídeo já entrou limpo pelo
# ClipSanitizer: assim o envio não espera a recompressão. Vídeo que já é pequeno
# (720p ou menos e com pouca informação por segundo) fica como está.
class ClipTranscoder
  class Error < StandardError; end

  MAX_SHORT_SIDE  = 720       # 1280x720 deitado, 720x1280 em pé
  MAX_FPS         = 30
  SKIP_BELOW_BITS = 3_500_000 # bits por segundo: abaixo disso, recomprimir não compensa
  TIMEOUT         = 15 * 60   # segundos; um vídeo longo da galeria leva alguns minutos

  def self.ffmpeg = Rails.configuration.x.flipaai.ffmpeg_path

  # O ffprobe vem junto com o ffmpeg, na mesma pasta.
  def self.ffprobe
    ffmpeg = self.ffmpeg
    ffmpeg.include?("/") || ffmpeg.include?("\\") ? File.join(File.dirname(ffmpeg), "ffprobe") : "ffprobe"
  end

  def initialize(path)
    @path = path
  end

  # Vale a pena recomprimir? (maior que 720p ou com muita informação por segundo)
  def needed?
    video = probe
    short_side = [ video[:width], video[:height] ].min
    short_side > MAX_SHORT_SIDE || video[:bits_per_second] > SKIP_BELOW_BITS || video[:fps] > MAX_FPS + 1
  end

  # Escreve o vídeo recomprimido em output_path (MP4).
  def call(output_path)
    command = [
      self.class.ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-y", "-i", @path,
      "-map", "0:v:0", "-map", "0:a:0?",
      # O lado menor fica com até 720px, mantendo a proporção (e em pé continua em pé).
      "-vf", "scale='if(gte(iw,ih),-2,min(#{MAX_SHORT_SIDE},iw))':'if(gte(iw,ih),min(#{MAX_SHORT_SIDE},ih),-2)'",
      "-fpsmax", MAX_FPS.to_s,
      "-c:v", "libx264", "-preset", "veryfast", "-crf", "26", "-pix_fmt", "yuv420p",
      "-c:a", "aac", "-b:a", "96k", "-ac", "2",
      "-map_metadata", "-1", "-map_chapters", "-1", "-fflags", "+bitexact",
      "-movflags", "+faststart",
      "-f", "mp4", output_path
    ]
    run(command)
    raise Error, "o ffmpeg não gerou o vídeo" unless File.size?(output_path)
  end

  private

  def probe
    output = run([ self.class.ffprobe, "-v", "error", "-select_streams", "v:0",
                   "-show_entries", "stream=width,height,avg_frame_rate:format=duration,size", "-of", "json", @path ])
    data = JSON.parse(output)
    stream = data.dig("streams", 0) || raise(Error, "o arquivo não tem imagem")
    duration = data.dig("format", "duration").to_f
    num, den = stream["avg_frame_rate"].to_s.split("/").map(&:to_f)
    {
      width: stream["width"].to_i, height: stream["height"].to_i,
      fps: den.to_f.positive? ? num / den : 0,
      bits_per_second: duration.positive? ? data.dig("format", "size").to_f * 8 / duration : 0
    }
  end

  def run(command)
    Open3.popen2e(*command) do |stdin, log, wait|
      stdin.close
      reader = Thread.new { log.read }
      unless wait.join(TIMEOUT)
        Process.kill("KILL", wait.pid)
        raise Error, "passou de #{TIMEOUT}s"
      end
      raise Error, reader.value.to_s.last(500) unless wait.value.success?
      reader.value
    end
  rescue Errno::ENOENT
    raise Error, "ffmpeg/ffprobe não encontrado"
  end
end
