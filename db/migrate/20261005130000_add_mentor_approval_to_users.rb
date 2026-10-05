class AddMentorApprovalToUsers < ActiveRecord::Migration[8.1]
  def change
    # Quem aprovou o mentor (um administrador; vazio quando foi pelo terminal) e quando.
    add_reference :users, :mentor_approved_by, foreign_key: { to_table: :users }
    add_column :users, :mentor_approved_at, :datetime
  end
end
