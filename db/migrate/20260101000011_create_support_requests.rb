class CreateSupportRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :support_requests do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :maneuver, foreign_key: true
      t.integer :kind,   null: false                # injury / stuck / technical
      t.integer :status, null: false, default: 0    # open / handled
      t.string  :contact
      t.text    :message
      t.datetime :handled_at

      t.timestamps
    end
  end
end
