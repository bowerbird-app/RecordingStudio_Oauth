# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class RegisterOauthClient < RecordingStudio::Services::BaseService
      DEFAULT_NAME = "Self-registered app"
      PUBLIC_AUTH_METHOD = "none"
      SECRET_AUTH_METHODS = %w[client_secret_basic client_secret_post].freeze
      AUTH_METHODS = (SECRET_AUTH_METHODS + [PUBLIC_AUTH_METHOD]).freeze
      SUPPORTED_GRANT_TYPES = %w[authorization_code refresh_token].freeze
      SUPPORTED_RESPONSE_TYPES = %w[code].freeze

      def initialize(metadata:)
        @metadata = stringify_metadata(metadata)
      end

      private

      attr_reader :metadata

      def perform
        return oauth_failure("invalid_client_metadata", "Self-registered apps are turned off on this host") unless RecordingStudioOauth.configuration.allow_self_registered_apps?

        redirect_error = RedirectUriRules.self_registered_error(redirect_uris)
        return oauth_failure("invalid_redirect_uri", redirect_error) if redirect_error

        auth_method = token_endpoint_auth_method
        unless AUTH_METHODS.include?(auth_method)
          return oauth_failure(
            "invalid_client_metadata",
            "token_endpoint_auth_method must be #{AUTH_METHODS.join(', ')}"
          )
        end

        grant_error = unsupported_list_error("grant_types", grant_types, SUPPORTED_GRANT_TYPES)
        return grant_error if grant_error

        response_error = unsupported_list_error("response_types", response_types, SUPPORTED_RESPONSE_TYPES)
        return response_error if response_error

        confidential = SECRET_AUTH_METHODS.include?(auth_method)
        result = CreateOauthClient.call(
          name: client_name,
          redirect_uris: redirect_uris,
          confidential: confidential,
          allow_registration: false,
          self_registered: true,
          token_endpoint_auth_method: auth_method
        )
        return oauth_failure("invalid_client_metadata", result.error) unless result.success?

        success(registration_payload(result.value, auth_method: auth_method))
      end

      def redirect_uris
        Array(metadata["redirect_uris"])
      end

      def token_endpoint_auth_method
        metadata["token_endpoint_auth_method"].to_s.presence || PUBLIC_AUTH_METHOD
      end

      def grant_types
        metadata.key?("grant_types") ? Array(metadata["grant_types"]) : SUPPORTED_GRANT_TYPES
      end

      def response_types
        metadata.key?("response_types") ? Array(metadata["response_types"]) : SUPPORTED_RESPONSE_TYPES
      end

      def client_name
        metadata["client_name"].to_s.strip.presence || DEFAULT_NAME
      end

      def unsupported_list_error(field, values, allowed)
        extra = values.map(&:to_s) - allowed
        return if extra.empty?

        oauth_failure("invalid_client_metadata", "#{field} must be #{allowed.join(', ')}")
      end

      def registration_payload(created, auth_method:)
        client = created.fetch(:client)
        body = {
          client_id: client.client_id,
          client_id_issued_at: client.created_at.to_i,
          client_name: client.name,
          redirect_uris: client.redirect_uris,
          grant_types: SUPPORTED_GRANT_TYPES,
          response_types: SUPPORTED_RESPONSE_TYPES,
          token_endpoint_auth_method: auth_method
        }
        secret = created[:client_secret]
        if secret.present?
          body[:client_secret] = secret
          body[:client_secret_expires_at] = 0
        end
        body
      end

      def stringify_metadata(value)
        hash = if value.respond_to?(:to_unsafe_h)
                 value.to_unsafe_h
               elsif value.respond_to?(:to_h)
                 value.to_h
               else
                 {}
               end
        hash.stringify_keys
      end

      def oauth_failure(code, description)
        failure({ error: code, error_description: description })
      end

      def service_args
        { token_endpoint_auth_method: token_endpoint_auth_method }
      end
    end
  end
end
