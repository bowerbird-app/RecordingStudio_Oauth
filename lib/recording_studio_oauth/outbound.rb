# frozen_string_literal: true

require "recording_studio_oauth/outbound/provider"
require "recording_studio_oauth/outbound/https_url"
require "recording_studio_oauth/outbound/registry"
require "recording_studio_oauth/outbound/access"
require "recording_studio_oauth/outbound/live_connection"
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

    def connection_status(provider:, root:, actor:)
      row = LiveConnection.find(provider: provider, root: root, actor: actor)
      return :missing if row.nil?
      return :needs_reconnect if row.needs_reconnect?

      :active
    end

    def connection_id_for(provider:, root:, actor:)
      LiveConnection.find(provider: provider, root: root, actor: actor)&.id
    end
  end
end
