# Troca o vídeo do treino pela versão de 720p (ClipTranscoder), em segundo plano,
# logo depois do envio. Se der errado, o vídeo original (já limpo) continua valendo.
class TranscodeClipJob < ApplicationJob
  queue_as :default

  def perform(training_session)
    return unless training_session.clip.attached?

    blob = training_session.clip.blob
    return if blob.custom_metadata["transcoded"]

    blob.open do |file|
      transcoder = ClipTranscoder.new(file.path)
      # Cortado depois do começo: recomprime mesmo pequeno, para sumirem os quadros que o
      # corte sem recomprimir deixou escondidos antes do trecho (ClipSanitizer).
      next mark_done(blob) unless transcoder.needed? || blob.custom_metadata["cut_from_seconds"].to_f.positive?

      Tempfile.create([ "clip-720p", ".mp4" ], binmode: true) do |output|
        transcoder.call(output.path)
        # O vídeo pode ter sido apagado (ou trocado) enquanto recomprimia.
        next unless training_session.reload.clip.attached? && training_session.clip.blob == blob

        File.open(output.path, "rb") do |io|
          training_session.replace_clip_with(io, metadata: blob.custom_metadata.merge("transcoded" => true))
        end
      end
    end
  rescue ClipTranscoder::Error => e
    Rails.logger.warn("[TranscodeClipJob] treino #{training_session.id}: o vídeo ficou como chegou (#{e.message})")
  end

  private

  # Vídeo que já era pequeno: só marca para não tentar de novo.
  def mark_done(blob)
    blob.custom_metadata = blob.custom_metadata.merge("transcoded" => true)
    blob.save!
  end
end
