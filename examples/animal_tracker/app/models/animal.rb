class Animal < ApplicationRecord
  include Chronicle::Model

  datomic_attribute :name, :string
  datomic_attribute :species, :string

  has_many :animal_locations, dependent: :destroy

  validates :name, :species, presence: true
end
