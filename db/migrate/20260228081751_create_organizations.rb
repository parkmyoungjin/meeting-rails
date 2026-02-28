class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string  :name, null: false
      t.string  :subdomain, null: false
      t.string  :stripe_customer_id
      t.boolean :active, null: false, default: true
      t.bigint  :plan_id

      t.timestamps
    end
    add_index :organizations, :subdomain, unique: true
    add_index :organizations, :plan_id
  end
end
