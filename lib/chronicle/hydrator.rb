# frozen_string_literal: true

require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"

module Chronicle
  class Hydrator
    class << self
      # Main entry point for hydrating raw Datomic query or pull results into Active Record instances
      #
      # @param klass [Class] The Active Record model class
      # @param raw_results [Array] Results returned from Datomic transport #q or #pull
      # @param compiled_meta [Hash] Options/metadata from Datalog compiler (e.g. find_vars, pluck)
      # @return [Array<ActiveRecord::Base>, Array] Hydrated model instances or raw scalar values
      def hydrate(klass, raw_results, compiled_meta = {})
        return [] if raw_results.blank?

        if compiled_meta[:pluck]
          return hydrate_pluck(raw_results, compiled_meta)
        end

        find_vars = compiled_meta[:find_vars] || ["?e"]

        raw_results.map do |row|
          attributes, associations = extract_attributes_and_associations(klass, row, find_vars)
          record = instantiate_model(klass, attributes)
          hydrate_associations(record, associations) if record && associations.present?
          record
        end
      end

      private

      def hydrate_pluck(raw_results, compiled_meta)
        find_vars = compiled_meta[:find_vars] || []
        if find_vars.size == 1
          raw_results.map { |row| row.is_a?(Array) ? row.first : row }
        else
          raw_results.map { |row| row.is_a?(Array) ? row : [row] }
        end
      end

      def extract_attributes_and_associations(klass, row, find_vars)
        attributes = {}
        associations = {}

        if row.is_a?(Hash)
          # Datomic Entity Map (from pull query or entity map)
          row.each do |key, val|
            clean_key = normalize_key(key, klass)
            next unless clean_key

            if val.is_a?(Hash) || (val.is_a?(Array) && val.first.is_a?(Hash))
              # Nested entity reference (association)
              associations[clean_key] = val
            else
              attributes[clean_key] = val
            end
          end
        elsif row.is_a?(Array)
          # Tuple result corresponding to find_vars
          find_vars.each_with_index do |var_name, idx|
            attr_name = var_name.to_s.sub(/^\?/, "")
            if attr_name == "e"
              attributes["id"] = row[idx]
            else
              val = row[idx]
              if val.is_a?(Hash) || (val.is_a?(Array) && val.first.is_a?(Hash))
                associations[attr_name] = val
              else
                attributes[attr_name] = val
              end
            end
          end
        else
          # Single scalar (e.g. entity ID integer)
          attributes["id"] = row
        end

        [attributes, associations]
      end

      def normalize_key(key, klass)
        str_key = key.to_s.sub(/^:/, "")

        if str_key == "db/id" || str_key == "id"
          "id"
        elsif str_key.include?("/")
          # Namespace attribute like "user/name" -> "name"
          parts = str_key.split("/")
          parts.last
        else
          str_key
        end
      end

      def instantiate_model(klass, attributes)
        string_attributes = attributes.stringify_keys

        if klass.respond_to?(:instantiate)
          record = klass.instantiate(string_attributes)
          ensure_dirty_tracking_clean(record)
          record
        else
          record = klass.allocate
          if record.respond_to?(:init_with)
            record.init_with("attributes" => string_attributes, "new_record" => false)
          else
            string_attributes.each do |k, v|
              setter = "#{k}="
              record.public_send(setter, v) if record.respond_to?(setter)
            end
          end
          record
        end
      end

      def hydrate_associations(record, associations)
        associations.each do |assoc_name, val|
          reflection = if record.class.respond_to?(:reflect_on_association)
                         record.class.reflect_on_association(assoc_name.to_sym)
                       end

          target_klass = reflection ? reflection.klass : assoc_name.to_s.classify.safe_constantize

          next unless target_klass

          if val.is_a?(Array)
            child_records = val.map { |child_hash| hydrate(target_klass, [child_hash]).first }.compact
            set_association_target(record, reflection, assoc_name, child_records, is_collection: true)
          else
            child_record = hydrate(target_klass, [val]).first
            set_association_target(record, reflection, assoc_name, child_record, is_collection: false)
          end
        end
      end

      def set_association_target(record, reflection, assoc_name, target, is_collection:)
        if reflection && record.respond_to?(:association)
          assoc = record.association(reflection.name)
          assoc.target = target
          assoc.loaded!
        else
          # Fallback instance variable for plain objects
          record.instance_variable_set("@#{assoc_name}", target)
        end
      end

      def ensure_dirty_tracking_clean(record)
        if record.respond_to?(:clear_changes_information)
          record.clear_changes_information
        elsif record.respond_to?(:changes_applied)
          record.changes_applied
        end
      end
    end
  end
end
