# frozen_string_literal: true

require "recording_studio_oauth/version"
require "recording_studio_oauth/configuration"
require "recording_studio_oauth/protected_resource"
require "recording_studio_oauth/protected_resource_registry"

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
  end
end

require "recording_studio_oauth/engine"
