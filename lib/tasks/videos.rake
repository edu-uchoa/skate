# Limpa os vídeos guardados antes do ClipSanitizer existir: tira localização (GPS),
# data, aparelho e o nome original do arquivo, regravando no mesmo lugar (o
# original some). Os vídeos novos já chegam limpos. Pode rodar mais de uma vez.
#
#   bin/rails videos:limpar
namespace :videos do
  desc "Tira localização e outros metadados dos vídeos já guardados"
  task limpar: :environment do
    cleaned = failed = 0

    TrainingSession.with_clip.find_each do |training_session|
      blob = training_session.clip.blob
      blob.open do |file|
        result = ClipSanitizer.new({ io: file, filename: blob.filename.to_s, content_type: blob.content_type }).call
        blob.upload(result[:io])
        blob.update!(filename: result[:filename])
      ensure
        result&.dig(:io)&.close!
      end
      cleaned += 1
    rescue ClipSanitizer::Error => e
      failed += 1
      puts "Treino #{training_session.id}: não deu para limpar (#{e.reason}). Apague o vídeo se ele não abrir."
    end

    puts "#{cleaned} vídeo(s) limpo(s)#{", #{failed} com problema" if failed.positive?}."
  end
end
