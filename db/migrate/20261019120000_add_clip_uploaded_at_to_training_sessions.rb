# Prazo dos vídeos: cada vídeo fica guardado por 1 mês, contado da hora em que a
# pessoa enviou (TrainingSession::CLIP_RETENTION). Fica numa coluna própria porque a
# versão em 720p (TranscodeClipJob) troca o arquivo, e o prazo não pode recomeçar.
class AddClipUploadedAtToTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :training_sessions, :clip_uploaded_at, :datetime
    add_index :training_sessions, :clip_uploaded_at

    # Vídeos que já existem: o prazo conta de quando o arquivo chegou.
    up_only do
      execute <<~SQL
        UPDATE training_sessions
        SET clip_uploaded_at = (
          SELECT active_storage_blobs.created_at
          FROM active_storage_attachments
          JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id
          WHERE active_storage_attachments.record_type = 'TrainingSession'
            AND active_storage_attachments.record_id = training_sessions.id
            AND active_storage_attachments.name = 'clip'
        )
      SQL
    end
  end
end
