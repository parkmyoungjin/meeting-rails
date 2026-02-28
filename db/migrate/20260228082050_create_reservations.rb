class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations do |t|
      t.references :room, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.date :date
      t.time :start_time
      t.time :end_time
      t.string :organizer
      t.string :purpose
      t.string :password_digest

      t.timestamps
    end
    add_index :reservations, [ :room_id, :date ]
  end
end
