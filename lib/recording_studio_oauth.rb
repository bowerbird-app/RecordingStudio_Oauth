# frozen_string_literal: true

require "recording_studio_oauth/version"
require "recording_studio_oauth/configuration"
require "recording_studio_oauth/protected_resources"

module RecordingStudioOauth
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def register_protected_resource(identifier)
      ProtectedResources.register(identifier)
    end
  end
end

require "recording_studio_oauth/engine"
