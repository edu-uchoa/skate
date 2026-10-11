class CreateMeetups < ActiveRecord::Migration[8.1]
  def change
    # Rolês marcados no mapa de Picos: onde e quando a pessoa vai andar. Cada um
    # some depois do horário de fim (Meetup.purge_expired!): não guardamos o
    # histórico de onde ninguém andou.
    create_table :meetups do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :place_name, null: false
      t.decimal :latitude, precision: 9, scale: 6, null: false
      t.decimal :longitude, precision: 9, scale: 6, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :note
      t.string :share_token, null: false # link para os amigos (/role/:token)
      t.timestamps
    end

    add_index :meetups, :share_token, unique: true
    add_index :meetups, :ends_at
  end
end
