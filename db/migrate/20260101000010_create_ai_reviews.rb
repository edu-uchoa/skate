class CreateAiReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_reviews do |t|
      t.references :training_session, null: false, foreign_key: true, index: { unique: true }
      t.integer  :status, null: false, default: 0  # pending / processing / completed / failed
      t.text     :headline
      t.text     :strengths     # "O que você fez bem"
      t.text     :mistake       # "Onde foi o erro"
      t.text     :next_focus    # "Próxima sessão: foca só nisso"
      t.text     :raw_response
      t.string   :error_message
      t.datetime :completed_at

      t.timestamps
    end
  end
end
