# Vídeos dos treinos, sempre atrás do login: /videos/:id.
#
# Substitui os links do Active Storage, que abriam para qualquer pessoa, sem login
# e sem expirar (as rotas públicas dele estão desligadas em config/application.rb).
# Só o dono assiste e, se o dono é aprendiz, mentores e administradores. Cada vez
# que alguém que não é o dono abre o vídeo, fica registrado em ClipAccess.
class ClipsController < ApplicationController
  include ActionController::Live # send_stream: manda o vídeo inteiro sem carregar na memória

  MAX_CHUNK = 2.megabytes # o player pede o vídeo em pedaços (Range); limita cada um

  def show
    @training_session = TrainingSession.with_clip.find(params[:id])
    return head(:not_found) unless @training_session.clip_visible_to?(current_user)

    record_access
    blob = @training_session.clip.blob
    # Nome genérico: o nome original do arquivo pode ter o nome da pessoa.
    filename = "video.#{blob.filename.extension_without_delimiter.presence || "mp4"}"
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Accept-Ranges"] = "bytes"

    if request.headers["Range"].present?
      send_range(blob, filename)
    else
      response.headers["Content-Length"] = blob.byte_size.to_s
      send_stream(filename: filename, disposition: "inline", type: blob.content_type) do |stream|
        blob.download { |chunk| stream.write(chunk) }
      end
    end
  end

  # Apagam o dono e o administrador (mentor não). O arquivo sai do armazenamento na
  # hora (não fica para depois) e, se o vídeo ainda esperava o mentor, sai da fila.
  # O progresso na trilha e uma devolutiva já recebida continuam.
  def destroy
    training_session = TrainingSession.with_clip.find(params[:id])
    return head(:not_found) unless training_session.clip_deletable_by?(current_user)

    training_session.remove_clip!

    if training_session.user_id == current_user.id
      redirect_to zine_path, notice: "Vídeo apagado. Ninguém mais consegue ver."
    else
      Rails.logger.warn("[FlipaAi] administrador #{current_user.id} apagou o vídeo do treino #{training_session.id} (aprendiz #{training_session.user_id})")
      redirect_to mentor_zine_path, notice: "Vídeo do aprendiz apagado. Ninguém mais consegue ver."
    end
  end

  private

  def send_range(blob, filename)
    ranges = Rack::Utils.get_byte_ranges(request.headers["Range"], blob.byte_size)
    return head(:range_not_satisfiable) unless ranges&.one? && ranges.first.size.positive?

    range = ranges.first.begin..[ ranges.first.end, ranges.first.begin + MAX_CHUNK - 1 ].min
    response.headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{blob.byte_size}"
    send_data blob.download_chunk(range), type: blob.content_type, disposition: "inline",
                                          filename: filename, status: :partial_content
  end

  # O player pede o vídeo em vários pedaços: registra só o começo (sem Range ou bytes=0-).
  def record_access
    return if @training_session.user_id == current_user.id
    return unless request.headers["Range"].blank? || request.headers["Range"].start_with?("bytes=0-")

    @training_session.clip_accesses.create!(viewer: current_user, ip_address: request.remote_ip,
                                            user_agent: request.user_agent.to_s.first(255))
  end
end
