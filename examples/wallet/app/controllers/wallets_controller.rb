class WalletsController < ApplicationController
  before_action :set_wallet, only: %i[show deposit withdraw]

  def index
    @wallets = WalletAccount.order(:name)
    @entry_counts = WalletEntry.all.to_a.each_with_object(Hash.new(0)) do |entry, counts|
      counts[entry.wallet_id] += 1
    end
  end

  def show
    @entries = WalletEntry.where(wallet_id: @wallet.id).to_a.sort_by { |entry| entry.created_at || Time.at(0) }.reverse
  end

  def new
    @wallet = WalletAccount.new
  end

  def create
    @wallet = WalletAccount.new(wallet_params.merge(balance_cents: 0))

    if @wallet.save
      redirect_to wallet_path(@wallet), notice: 'Wallet created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def deposit
    record_entry(positive_amount, 'Deposit')
  end

  def withdraw
    record_entry(-positive_amount, 'Withdrawal')
  end

  private

  def set_wallet
    @wallet = WalletAccount.find(params[:id])
  end

  def wallet_params
    params.require(:wallet_account).permit(:name)
  end

  def positive_amount
    amount = params.require(:amount).to_d
    raise ArgumentError if amount <= 0

    (amount * 100).to_i
  end

  def record_entry(amount_cents, default_description)
    description = params[:description].presence || default_description
    @wallet.record_transaction!(amount_cents:, description:)
    redirect_to wallet_path(@wallet), notice: "#{default_description} recorded."
  rescue ArgumentError
    redirect_to @wallet, alert: 'Enter an amount greater than zero.'
  end
end
