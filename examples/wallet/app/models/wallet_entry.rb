class WalletEntry < ApplicationRecord
  belongs_to :wallet_account, class_name: "WalletAccount", foreign_key: :wallet_id

  validates :description, presence: true
end
