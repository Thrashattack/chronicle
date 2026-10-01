wallet = WalletAccount.find_or_create_by!(name: "Everyday wallet")
if wallet.wallet_entries.empty?
	wallet.record_transaction!(amount_cents: 125_000, description: "Opening deposit")
	wallet.record_transaction!(amount_cents: -2_450, description: "Coffee and pastry")
	wallet.record_transaction!(amount_cents: 32_000, description: "Freelance payment")
end
