class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :floor
      t.string :name
      t.integer :capacity
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :rooms, [ :organization_id, :floor ]
  end
end
