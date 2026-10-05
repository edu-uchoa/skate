class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    # 0 = aprendiz (toda conta nova), 1 = mentor (só por bin/rails "mentor:promover[...]").
    add_column :users, :role, :integer, default: 0, null: false
  end
end
