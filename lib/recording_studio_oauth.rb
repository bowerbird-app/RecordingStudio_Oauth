# frozen_string_literal: true

require "recording_studio_oauth/version"
require "recording_studio_oauth/copy"
require "recording_studio_oauth/configuration"
require "recording_studio_oauth/protected_resource"
require "recording_studio_oauth/protected_resource_registry"
require "recording_studio_oauth/return_url_rules"
require "recording_studio_oauth/redirect_uri_rules"
require "recording_studio_oauth/register_rate_limit"
require "recording_studio_oauth/central_relay_state"
require "recording_studio_oauth/central_relay"
require "recording_studio_oauth/registration_policy"
require "recording_studio_oauth/outbound"
require "recording_studio_oauth/inbound"

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

    def registration_allowed?(client_id:)
      client = OauthClient.find_by(client_id: client_id.to_s)
      RegistrationPolicy.allowed?(client)
    end

    def registration_options(client_id:, base_url:)
      client = OauthClient.find_by(client_id: client_id.to_s)
      RegistrationPolicy.payload(client, base_url: base_url)
    end

    def registration_url(base_url:)
      RegistrationPolicy.registration_url(base_url: base_url)
    end

    def verify_session_token(**)
      Services::VerifySessionToken.call(**)
    end

    def record_external_install(**)
      Services::RecordExternalInstall.call(**)
    end

    def register_outbound_provider(**)
      Outbound.register_provider(**)
    end

    def outbound_providers
      Outbound.providers
    end

    def connection_for(provider:, root:, actor:)
      Outbound.connection_for(provider: provider, root: root, actor: actor)
    end

    def connection_status(provider:, root:, actor:)
      Outbound.connection_status(provider: provider, root: root, actor: actor)
    end

    def combined_connection_status(provider:, root:, actor:)
      Outbound.combined_connection_status(provider: provider, root: root, actor: actor)
    end

    def inbound_connection_status(plugin_key:, root:, actor:)
      Inbound.connection_status(plugin_key: plugin_key, root: root, actor: actor)
    end

    def inbound_connections(plugin_key:, root:, actor:)
      Inbound.connections(plugin_key: plugin_key, root: root, actor: actor)
    end

    def connection_id_for(provider:, root:, actor:)
      Outbound.connection_id_for(provider: provider, root: root, actor: actor)
    end

    def connected_user_count(provider:, root:)
      Outbound.connected_user_count(provider: provider, root: root)
    end
  end
end

require "recording_studio_oauth/engine"
require "recording_studio_oauth/metrics"
