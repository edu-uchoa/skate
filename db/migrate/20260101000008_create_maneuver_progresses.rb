class CreateManeuverProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :maneuver_progresses do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :maneuver, null: false, foreign_key: true
      t.integer  :status, null: false, default: 0  # locked / available / in_progress / completed
      t.integer  :attempts_count, null: false, default: 0
      t.datetime :completed_at

      t.timestamps
    end

    add_index :maneuver_progresses, [ :user_id, :maneuver_id ], unique: true
  end
end
