# Lista de acesso: os e-mails que o super admin libera no painel para usar o app
# publicado (AllowedEmail). Quem não está nela não cria conta nem entra.
class CreateAllowedEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :allowed_emails do |t|
      t.string :email, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
