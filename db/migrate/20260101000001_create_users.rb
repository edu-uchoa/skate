class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Todo visitante vira um User anônimo no primeiro acesso (perfil temporário).
      t.string   :token, null: false
      t.string   :email
      t.string   :phone
      t.integer  :birth_year
      t.datetime :terms_accepted_at
      t.datetime :registered_at   # nil => perfil temporário / anônimo
      t.datetime :last_seen_at
      t.string   :time_zone, default: "America/Sao_Paulo", null: false

      t.timestamps
    end

    add_index :users, :token, unique: true
    add_index :users, :email, unique: true, where: "email IS NOT NULL"
    add_index :users, :phone, unique: true, where: "phone IS NOT NULL"
  end
end
