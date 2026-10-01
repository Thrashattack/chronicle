class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.integer :customer_id, null: false
      t.string :description, null: false
      t.integer :amount_cents, null: false
      t.timestamps
    end

    add_index :purchases, :customer_id
  end
end
