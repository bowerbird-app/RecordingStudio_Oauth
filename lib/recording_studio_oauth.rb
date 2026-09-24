# frozen_string_literal: true

require "recording_studio_oauth/version"
require "recording_studio_oauth/configuration"
require "recording_studio_oauth/protected_resource"
require "recording_studio_oauth/protected_resource_registry"
require "recording_studio_oauth/return_url_rules"
require "recording_studio_oauth/central_relay_state"
require "recording_studio_oauth/central_relay"
require "recording_studio_oauth/registration_policy"

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
  end
end

require "recording_studio_oauth/engine"
