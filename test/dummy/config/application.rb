require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    secret = credentials.secret_key_base.to_s
    if secret.present? && config.active_record.encryption.primary_key.blank?
      config.active_record.encryption.primary_key = secret[0, 32]
      config.active_record.encryption.deterministic_key = (secret[32, 32].presence || secret[0, 32])
      config.active_record.encryption.key_derivation_salt = secret[-32, 32].presence || secret[0, 32]
    end

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Configure generators to use UUID primary keys
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
