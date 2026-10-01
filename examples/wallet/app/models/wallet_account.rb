class WalletAccount < DatomicRecord
  include Chronicle::Model

  self.table_name = "wallets"

  datomic_attribute :name, :string
  datomic_attribute :balance_cents, :integer

  has_many :wallet_entries, dependent: :destroy, foreign_key: :wallet_id

  validates :name, presence: true

  def record_transaction!(amount_cents:, description:)
    transaction do
      update!(balance_cents: balance_cents + amount_cents)
      wallet_entries.create!(amount_cents:, balance_cents:, description:)
    end
  end
end
