class CreateWallets < ActiveRecord::Migration[8.1]
  def change
    create_table :wallets do |t|
      t.string :name, null: false
      t.integer :balance_cents, null: false, default: 0
      t.timestamps
    end

    create_table :wallet_entries do |t|
      t.references :wallet, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.integer :balance_cents, null: false
      t.string :description, null: false
      t.timestamps
    end
  end
end
