# frozen_string_literal: true

module Chronicle
  class Railtie < Rails::Railtie
    initializer "chronicle.register_adapter" do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::ConnectionAdapters.register(
          "datomic",
          "ActiveRecord::ConnectionAdapters::DatomicAdapter",
          "chronicle/connection_adapters/datomic_adapter"
        )
      end
    end
  end
end
