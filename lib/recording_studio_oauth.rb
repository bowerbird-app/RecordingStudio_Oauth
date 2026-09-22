# frozen_string_literal: true

require "recording_studio_oauth/version"
require "recording_studio_oauth/configuration"
require "recording_studio_oauth/protected_resource"
require "recording_studio_oauth/protected_resource_registry"
require "recording_studio_oauth/return_url_rules"
require "recording_studio_oauth/central_relay_state"
require "recording_studio_oauth/central_relay"

module RecordingStudioOauth
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def protected_resources(api_key: "public")
      ProtectedResourceRegistry.build(configuration: configuration, api_key: api_key)
    end

    def central_relay_connect_url(base_url:)
      CentralRelay.connect_url(base_url: base_url)
    end

    def central_relay_callback_url(base_url:)
      CentralRelay.callback_url(base_url: base_url)
    end
  end
end

require "recording_studio_oauth/engine"
