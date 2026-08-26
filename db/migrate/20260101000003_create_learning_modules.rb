class CreateLearningModules < ActiveRecord::Migration[8.1]
  def change
    # "Module" é palavra reservada em Ruby, por isso LearningModule.
    create_table :learning_modules do |t|
      t.string  :code,     null: false          # "0", "1", "2"...
      t.string  :name,     null: false          # "FUNDAMENTOS"
      t.string  :subtitle
      t.text    :description
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :learning_modules, :code, unique: true
    add_index :learning_modules, :position
  end
end
