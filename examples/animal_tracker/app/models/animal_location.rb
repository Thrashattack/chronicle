class AnimalLocation < ApplicationRecord
  include Chronicle::Model

  datomic_attribute :animal_id, :integer
  datomic_attribute :latitude, :float
  datomic_attribute :longitude, :float
  datomic_attribute :recorded_at, :instant

  belongs_to :animal, optional: true

  scope :chronological, -> { order(recorded_at: :asc) }
end
