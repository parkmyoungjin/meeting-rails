class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :name
      t.integer :price_cents
      t.integer :room_limit
      t.string :stripe_price_id

      t.timestamps
    end
  end
end
