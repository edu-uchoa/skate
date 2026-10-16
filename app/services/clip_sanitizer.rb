# Limpa o vídeo antes de guardar: tira a localização (GPS), a data, o modelo do
# celular e qualquer outro metadado, e deixa só a imagem e o som.
#
# Vídeo de celular costuma levar o lugar onde foi gravado; no vídeo de um
# adolescente, isso pode revelar onde ele mora. O ffmpeg copia a imagem e o som
# para um arquivo novo, sem recomprimir (é rápido e não perde qualidade), e o
# original nunca chega ao armazenamento. A rotação do vídeo (em pé ou deitado) é
# mantida. O arquivo também perde o nome original, que pode ter o nome da pessoa.
#
# Precisa do ffmpeg instalado (veja o README). Sem ele, o vídeo é recusado: é
# melhor não receber do que guardar com a localização.
class ClipSanitizer
  class Error < StandardError
    # :format, :size, :unreadable ou :unavailable (TrainingSession::CLIP_PROBLEMS)
    attr_reader :reason

    def initialize(reason, detail = nil)
      @reason = reason
      super(detail || reason.to_s)
    end
  end

  # Formato detectado no arquivo => [formato de saída do ffmpeg, extensão].
  FORMATS = {
    "video/mp4"       => %w[mp4 mp4],
    "video/x-m4v"     => %w[mp4 m4v],
    "video/quicktime" => %w[mov mov],
    "video/webm"      => %w[webm webm]
  }.freeze

  TIMEOUT = 60 # segundos; copiar um vídeo de 15s leva menos de um

  def self.ffmpeg = Rails.configuration.x.flipaai.ffmpeg_path

  # attachable: o arquivo enviado pelo navegador ou { io:, filename:, content_type: }.
  def initialize(attachable, max_bytes: nil)
    @attachable = attachable
    @max_bytes  = max_bytes
  end

  # Devolve o vídeo limpo, no formato que o Active Storage aceita no attach.
  def call
    path = source_path
    raise Error, :size if max_bytes && File.size(path) > max_bytes

    content_type = Marcel::MimeType.for(Pathname.new(path), name: declared_filename, declared_type: declared_content_type)
    muxer, extension = FORMATS[content_type]
    raise Error, :format unless muxer

    output = Tempfile.new([ "video", ".#{extension}" ], binmode: true)
    output.close # o ffmpeg escreve no caminho; reabre depois para o Active Storage ler
    run(path, output.path, muxer)
    output.open
    output.binmode

    { io: output, filename: "video.#{extension}", content_type: content_type }
  rescue Error
    output&.close!
    raise
  ensure
    @copy&.close!
  end

  private

  attr_reader :attachable, :max_bytes

  def io = attachable.is_a?(Hash) ? attachable[:io] : attachable
  def declared_filename     = attachable.is_a?(Hash) ? attachable[:filename].to_s : attachable.try(:original_filename).to_s
  def declared_content_type = attachable.is_a?(Hash) ? attachable[:content_type] : attachable.try(:content_type)

  # O ffmpeg lê de um arquivo: usa o temporário do upload ou copia o conteúdo para um.
  def source_path
    raise Error, :format unless io.respond_to?(:read)
    return io.path if io.respond_to?(:path) && io.path.present?

    io.rewind if io.respond_to?(:rewind)
    @copy = Tempfile.new("clip", binmode: true)
    IO.copy_stream(io, @copy)
    @copy.flush
    @copy.path
  end

  def run(input, output, muxer)
    command = [
      self.class.ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-y", "-i", input,
      "-map", "0:v:0", "-map", "0:a:0?",            # só a imagem e o som (sem trilhas de dados)
      "-c", "copy",                                  # sem recomprimir
      "-map_metadata", "-1", "-map_chapters", "-1",  # nenhum metadado: GPS, data, aparelho, título
      "-fflags", "+bitexact",                        # nem a assinatura do próprio ffmpeg
      *([ "-movflags", "+faststart" ] if muxer.in?(%w[mp4 mov])), # começa a tocar antes de baixar tudo
      "-f", muxer, output
    ]

    Open3.popen2e(*command) do |stdin, log, wait|
      stdin.close
      reader = Thread.new { log.read }
      unless wait.join(TIMEOUT)
        Process.kill("KILL", wait.pid)
        raise Error.new(:unreadable, "ffmpeg passou de #{TIMEOUT}s")
      end
      next if wait.value.success? && File.size?(output)

      Rails.logger.warn("[ClipSanitizer] o ffmpeg não leu o vídeo: #{reader.value.to_s.last(500)}")
      raise Error, :unreadable
    end
  rescue Errno::ENOENT
    Rails.logger.error("[ClipSanitizer] ffmpeg não encontrado (#{self.class.ffmpeg}). Instale o ffmpeg: sem ele nenhum vídeo é aceito.")
    raise Error, :unavailable
  end
end
