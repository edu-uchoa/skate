class CreateAccessCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :access_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string   :destination, null: false  # e-mail ou telefone informado
      t.integer  :channel,     null: false, default: 0  # email / whatsapp
      t.string   :code_digest, null: false
      t.integer  :attempts,    null: false, default: 0
      t.datetime :expires_at,  null: false
      t.datetime :consumed_at

      t.timestamps
    end

    add_index :access_codes, [ :user_id, :created_at ]
  end
end
