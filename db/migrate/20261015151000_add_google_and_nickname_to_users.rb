# Entrar com o Google e o nickname#0000.
#   google_uid:   o identificador da conta Google (o "sub"), que não muda nunca
#   nickname:     como a pessoa aparece no app (pode repetir entre usuários)
#   nickname_key: o nickname em minúsculas, para comparar e procurar
#   nickname_tag: os 4 números depois do "#", que separam nicknames iguais
class AddGoogleAndNicknameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_uid, :string
    add_column :users, :nickname, :string
    add_column :users, :nickname_key, :string
    add_column :users, :nickname_tag, :string

    add_index :users, :google_uid, unique: true, where: "google_uid IS NOT NULL"
    add_index :users, %i[nickname_key nickname_tag], unique: true, where: "nickname_key IS NOT NULL"
  end
end
