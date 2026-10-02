class PurchasesController < ApplicationController
  PAGE_SIZE = 25

  def index
    @total_purchases = Purchase.count
    @total_pages = (@total_purchases.to_f / PAGE_SIZE).ceil
    @page = params[:page].to_i.clamp(1, [@total_pages, 1].max)
    @first_purchase = @total_purchases.zero? ? 0 : ((@page - 1) * PAGE_SIZE) + 1
    @last_purchase = [@page * PAGE_SIZE, @total_purchases].min
    @purchases = Purchase.order(created_at: :desc, id: :desc)
                          .limit(PAGE_SIZE)
                          .offset((@page - 1) * PAGE_SIZE)
  end

  def new
    @purchase = Purchase.new
    @customers = DatomicCustomer.order(:name)
  end

  def create
    customer = DatomicCustomer.find(params.require(:purchase).fetch(:customer_id))
    purchase_attributes = purchase_params

    Chronicle::TransactionCoordinator.transact(transport: DatomicCustomer.chronicle_transport) do |transaction|
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
