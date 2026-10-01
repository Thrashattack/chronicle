require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module AnimalTracker
  class Application < Rails::Application
    config.load_defaults 8.1
    config.active_record.migration_error = false
    config.middleware.delete ActiveRecord::Migration::CheckPending
    config.autoload_lib(ignore: %w[assets tasks])
    config.generators.system_tests = nil
  end
end
