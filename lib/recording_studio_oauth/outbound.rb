# frozen_string_literal: true

require "recording_studio_oauth/outbound/provider"
require "recording_studio_oauth/outbound/registry"
require "recording_studio_oauth/outbound/access"
require "recording_studio_oauth/outbound/handshake"
require "recording_studio_oauth/outbound/token_client"

module RecordingStudioOauth
  module Outbound
    module_function

    def registry
      @registry ||= Registry.new
    end

    def register_provider(**)
      registry.register(**)
    end

    def provider(key)
      registry.fetch(key)
    end

    def reset_providers!
      registry.reset!
    end

    def connection_for(provider:, root:, actor:)
      Services::LookupOutboundConnection.call(provider: provider, root: root, actor: actor).value
    end
  end
end
