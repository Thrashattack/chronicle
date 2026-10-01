class Purchase < ApplicationRecord
  validates :customer_id, :description, :amount_cents, presence: true
  validate :customer_exists_in_datomic

  def customer
    DatomicCustomer.find(customer_id)
  end

  private

  def customer_exists_in_datomic
    DatomicCustomer.find(customer_id)
  rescue ActiveRecord::RecordNotFound
    errors.add(:customer_id, "must reference an existing Datomic customer")
  end
end
