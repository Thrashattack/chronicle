class DatomicCustomer < DatomicRecord
  include Chronicle::Model

  self.table_name = "customers"

  datomic_attribute :name, :string
  datomic_attribute :email, :string

  validates :name, :email, presence: true
end
