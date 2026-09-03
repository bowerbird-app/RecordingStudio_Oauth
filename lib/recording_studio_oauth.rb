# frozen_string_literal: true

require "recording_studio_oauth/version"
require "recording_studio_oauth/configuration"

module RecordingStudioOauth
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end
  end
end

require "recording_studio_oauth/engine"
