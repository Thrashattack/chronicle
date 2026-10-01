class DatomicCustomer < ApplicationRecord
  include Chronicle::Model

  self.table_name = "customers"
  connects_to database: { writing: :datomic, reading: :datomic }

  datomic_attribute :name, :string
  datomic_attribute :email, :string

  validates :name, :email, presence: true
end
