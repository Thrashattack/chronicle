class PurchasesController < ApplicationController
  def index
    @purchases = Purchase.order(created_at: :desc)
  end

  def new
    @purchase = Purchase.new
    @customers = DatomicCustomer.order(:name)
  end

  def create
    customer = DatomicCustomer.find(params.require(:purchase).fetch(:customer_id))
    purchase_attributes = purchase_params

    Chronicle::TransactionCoordinator.transaction do |transaction|
      transaction.datomic(customer)
      transaction.sqlite do
        Purchase.create!(purchase_attributes)
      end
    end

    redirect_to purchases_path, notice: "Purchase recorded across Datomic and SQLite."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, Chronicle::TransactionError => e
    @purchase = Purchase.new(purchase_attributes || {})
    @customers = DatomicCustomer.order(:name)
    @purchase.errors.add(:base, e.message)
    render :new, status: :unprocessable_content
  end

  private

  def purchase_params
    params.require(:purchase).permit(:customer_id, :description, :amount_cents)
  end
end
