class AddMentorRequestToUsers < ActiveRecord::Migration[8.1]
  def change
    # Pedido de mentor feito no cadastro: fica pendente até um mentor aprovar.
    add_column :users, :mentor_requested_at, :datetime
    add_column :users, :mentor_request_note, :text
  end
end
