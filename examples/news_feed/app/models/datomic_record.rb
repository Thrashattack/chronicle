class DatomicRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :datomic, reading: :datomic } unless ENV['CHRONICLE_USE_DATOMIC'] == 'false'
end
