# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class StartWordPressRelay < RecordingStudio::Services::BaseService
      def initialize(
        client_id:,
        return_to:,
        relay_callback_url:,
        code_challenge:,
        code_challenge_method: Pkce::S256,
        site_state: nil,
        response_type: "code",
        resource: nil,
        resolve_client: nil,
        state_secret: nil
      )
        @client_id = client_id.to_s
        @return_to = return_to.to_s
        @relay_callback_url = relay_callback_url.to_s
        @code_challenge = code_challenge.to_s.presence
        @code_challenge_method = code_challenge_method.to_s.presence || Pkce::S256
        @site_state = site_state.to_s.presence
        @response_type = response_type.to_s.presence || "code"
        @resource = resource.to_s.presence
        @resolve_client = resolve_client
        @state_secret = state_secret
      end

      private

      attr_reader :client_id, :return_to, :relay_callback_url, :code_challenge, :code_challenge_method,
                  :site_state, :response_type, :resource, :resolve_client, :state_secret

      def perform
        return oauth_failure("unsupported_response_type", "response_type must be code") unless response_type == "code"

        client = lookup_client
        return client if client.is_a?(Result)

        callback = WordPressCallbackUrl.parse(return_to)
        return oauth_failure("invalid_request", "That WordPress return address is not allowed.") if callback.nil?
        return oauth_failure("invalid_request", "This app is not set up for WordPress Connect.") unless client.redirect_uri_allowed?(relay_callback_url)
        return oauth_failure("invalid_request", "Connect needs a proof key.") unless pkce_allowed?

        state = WordPressRelayState.new(
          return_to: callback.to_s,
          client_id: client.client_id,
          code_challenge: code_challenge,
          site_state: site_state
        ).sign(secret: state_secret)

        success(
          client_id: client.client_id,
          api_key: client.api_key.to_s,
          redirect_uri: relay_callback_url,
          state: state,
          code_challenge: code_challenge,
          code_challenge_method: Pkce::S256,
          resource: resource
        )
      end

      def lookup_client
        return oauth_failure("invalid_client", "This app is not registered.") if client_id.blank?

        client = resolve_client ? resolve_client.call(client_id) : OauthClient.find_by(client_id: client_id)
        return oauth_failure("invalid_client", "This app is not registered.") if client.nil? || client.revoked?

        client
      end

      def pkce_allowed?
        code_challenge.present? && code_challenge_method == Pkce::S256
      end

      def oauth_failure(code, description)
        failure({ error: code, error_description: description })
      end

      def service_args
        { client_id: client_id, relay_callback_url: relay_callback_url }
      end
    end
  end
end
