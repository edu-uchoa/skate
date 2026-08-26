class CreateDiagnoses < ActiveRecord::Migration[8.1]
  def change
    create_table :diagnoses do |t|
      t.references :user, null: false, foreign_key: true
      t.integer  :level          # nunca subi / consigo remar / travado no ollie
      t.integer  :setup          # sem skate / de loja / skateshop / outro
      t.datetime :completed_at

      t.timestamps
    end
  end
end
