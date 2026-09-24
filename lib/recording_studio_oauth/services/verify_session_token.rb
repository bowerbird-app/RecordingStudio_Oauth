# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class VerifySessionToken < RecordingStudio::Services::BaseService
      def initialize(token:, client_id: nil, client: nil, expected_external_id: nil, secret: nil, now: nil)
        @token = token.to_s
        @client_id = client_id.to_s.presence
        @client = client
        @expected_external_id = expected_external_id.to_s.presence
        @secret = secret.to_s.presence
        @now = now
      end

      private

      attr_reader :token, :client_id, :expected_external_id, :secret, :now

      def perform
        resolved = resolve_client
        return resolved if resolved.failure?

        client = resolved.value
        verify_secret = secret.presence || client.session_token_secret
        return fail_with("session token verify is not configured", :missing_config) if verify_secret.blank?
        return fail_with("session token verify is not configured", :missing_config) if client.session_token_audience.blank?
        return fail_with("invalid token", :invalid_token) if token.blank?

        status, claims = Hs256Jwt.decode(
          token,
          verify_secret,
          now: now || Time.now.to_i,
          audience: client.session_token_audience
        )
        return fail_with(message_for(status), status) unless status == :ok

        session_token = SessionToken.new(claims: claims, provider: client.session_token_provider)
        shopify_error = shopify_error_for(session_token)
        return fail_with(message_for(shopify_error), shopify_error) if shopify_error
        unless session_token.matches_external_id?(expected_external_id)
          return fail_with(message_for(:external_id_mismatch), :external_id_mismatch)
        end
        return fail_with("invalid token", :invalid_token) if session_token.external_id.blank?

        success(
          client: client,
          claims: claims,
          external_id: session_token.external_id,
          provider: session_token.provider
        )
      end

      def resolve_client
        found = @client || OauthClient.find_by(client_id: client_id.to_s)
        return fail_with("unknown client", :unknown_client) if found.nil?
        return fail_with("client is revoked", :revoked) if found.revoked?

        success(found)
      end

      def shopify_error_for(session_token)
        return unless session_token.shopify?
        return :invalid_token if session_token.dest_host.blank? || session_token.iss_host.blank?
        return :iss_mismatch unless session_token.shopify_hosts_match?

        nil
      end

      def fail_with(message, code)
        failure(message, errors: [code])
      end

      def message_for(code)
        {
          invalid_token: "invalid token",
          bad_signature: "bad signature",
          wrong_audience: "wrong audience",
          expired: "expired",
          not_yet_valid: "not yet valid",
          iss_mismatch: "issuer and destination do not match",
          external_id_mismatch: "shop does not match"
        }.fetch(code, "invalid token")
      end

      def service_args
        { client_id: @client&.client_id || client_id }
      end
    end
  end
end
