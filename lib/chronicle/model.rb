# frozen_string_literal: true

module Chronicle
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :datomic_attributes, default: {}
    end

    module ClassMethods
      def datomic_attribute(name, type = :string, options = {})
        self.datomic_attributes = datomic_attributes.merge(name.to_sym => { type:, options: })

        define_method(name) do
          read_attribute(name)
        end

        define_method("#{name}=") do |val|
          write_attribute(name, val)
        end
      end

      def as_of(time_or_t)
        all.extending(TimeTravelExtension).spawn.tap do |rel|
          rel.time_travel_options = { as_of: time_or_t }
        end
      end

      def since(time_or_t)
        all.extending(TimeTravelExtension).spawn.tap do |rel|
          rel.time_travel_options = { since: time_or_t }
        end
      end

      def chronicle_transport
        Chronicle::Transport.client
      end
    end

    module TimeTravelExtension
      include Relation

      attr_accessor :time_travel_options
    end

    def datomic_entity_id
      read_attribute(:id)
    end

    def to_datoms
      datoms = []
      self.class.datomic_attributes.each_key do |attr_name|
        val = public_send(attr_name)
        next if val.nil?

        attr_ident = ":#{self.class.name.underscore}/#{attr_name}"
        datoms << [':db/add', datomic_entity_id || ':temp_id', attr_ident, val]
      end
      datoms
    end
  end
end
