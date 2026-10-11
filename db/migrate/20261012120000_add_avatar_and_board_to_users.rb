class AddAvatarAndBoardToUsers < ActiveRecord::Migration[8.1]
  def change
    # Escolhas do perfil: o avatar de skatista (Avatar) e o skate (Deck). Valores
    # fora das listas de opções voltam para o padrão, então {} já é um avatar pronto.
    add_column :users, :avatar_options, :json, default: {}, null: false
    add_column :users, :board_options, :json, default: {}, null: false
  end
end
