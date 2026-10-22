# frozen_string_literal: true

module RecordingStudioOauth
  module Outbound
    class Provider
      attr_reader :key, :authorize_url, :token_url, :scopes, :client_id, :client_secret,
                  :pkce, :refresh, :revoke_url, :extra_authorize_params, :http

      def initialize(key:, authorize_url:, token_url:, scopes:, client_id:, client_secret:,
                     pkce:, refresh:, revoke_url:, extra_authorize_params:, http:)
        @key = key
        @authorize_url = authorize_url
        @token_url = token_url
        @scopes = scopes
        @client_id = client_id
        @client_secret = client_secret
        @pkce = pkce
        @refresh = refresh
        @revoke_url = revoke_url
        @extra_authorize_params = extra_authorize_params
        @http = http
        freeze
      end

      def pkce?
        pkce == true
      end

      def refresh?
        refresh == true
      end

      def revoke?
        revoke_url.present?
      end
    end
  end
end
