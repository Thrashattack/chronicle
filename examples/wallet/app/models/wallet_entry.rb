class WalletEntry < DatomicRecord
  include Chronicle::Model

  datomic_attribute :wallet_id, :integer
  datomic_attribute :amount_cents, :integer
  datomic_attribute :balance_cents, :integer
  datomic_attribute :description, :string
  datomic_attribute :created_at, :instant
  datomic_attribute :updated_at, :instant

  belongs_to :wallet_account, class_name: "WalletAccount", foreign_key: :wallet_id, optional: true

  validates :description, presence: true
end
