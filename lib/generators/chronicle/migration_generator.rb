# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module Chronicle
  module Generators
    class MigrationGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"

      def create_migration_file
        migration_dir = File.join("db", "migrate")
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        file_path = File.join(migration_dir, "#{timestamp}_#{file_name}.rb")

        template "migration.rb.erb", file_path
      end

      private

      def migration_class_name
        file_name.camelize
      end

      def entity_name
        file_name.sub(/^create_/, "").sub(/^add_.*_to_/, "").singularize
      end

      def parse_attribute(attr_str)
        parts = attr_str.split(":")
        name = parts[0]
        type = parts[1] || "string"
        options = {}

        if parts[2] == "index" || parts[2] == "uniq" || parts[2] == "unique"
          options[:index] = true
          options[:unique] = :identity if parts[2].start_with?("uniq")
        end

        { name: name, type: type, options: options }
      end
    end
  end
end
