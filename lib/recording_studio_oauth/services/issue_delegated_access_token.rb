# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class IssueDelegatedAccessToken < RecordingStudio::Services::BaseService
      SUPPORTED_GRANT_TYPES = %w[authorization_code refresh_token].freeze

      def initialize(grant_type:, client_id:, client_secret: nil, api: :public, code: nil, redirect_uri: nil, code_verifier: nil, refresh_token: nil, resource: nil)
        @grant_type = grant_type.to_s
        @client_id = client_id.to_s
        @client_secret = client_secret.to_s.presence
        @api_key = api.to_s
        @code = code.to_s.presence
        @redirect_uri = redirect_uri.to_s.presence
        @code_verifier = code_verifier.to_s.presence
        @refresh_token = refresh_token.to_s.presence
        @resource = resource.to_s.presence
      end

      private

      attr_reader :grant_type, :client_id, :client_secret, :api_key, :code, :redirect_uri, :code_verifier, :refresh_token, :resource

      def perform
        return oauth_failure("invalid_request", "grant_type is required") if grant_type.blank?
        return oauth_failure("unsupported_grant_type", "grant_type must be #{SUPPORTED_GRANT_TYPES.join(', ')}") unless SUPPORTED_GRANT_TYPES.include?(grant_type)

        case grant_type
        when "authorization_code"
          issue_authorization_code
        when "refresh_token"
          issue_refresh_token
        end
      rescue ActiveRecord::ActiveRecordError
        failure(OauthErrorMapper.server_error_payload)
      end

      def issue_authorization_code
        client_result = authenticate_client
        return client_result if client_result.failure?

        client = client_result.value
        return oauth_failure("invalid_request", "code is required") if code.blank?
        return oauth_failure("invalid_request", "redirect_uri is required") if redirect_uri.blank?
        return oauth_failure("invalid_grant", "authorization code is invalid") unless AuthorizationCode.valid_format?(code)

        stored = AuthorizationCode.find_by_token(OauthAuthorizationCode, code)
        return oauth_failure("invalid_grant", "authorization code is invalid") if stored.nil?

        authorization = stored.oauth_authorization
        return oauth_failure("invalid_grant", "authorization code is invalid") unless authorization.oauth_client_id == client.id
        return oauth_failure("invalid_grant", "redirect_uri does not match") unless stored.redirect_uri == redirect_uri

        if stored.used?
          VoidOauthAuthorization.call(authorization: authorization)
          return oauth_failure("invalid_grant", "authorization code has already been used")
        end
        return oauth_failure("invalid_grant", "authorization code has expired") if stored.expired?
        return oauth_failure("invalid_grant", "authorization is inactive") unless authorization.active?

        pkce_result = verify_pkce(client: client, stored: stored)
        return pkce_result if pkce_result != true

        reused = false
        inactive = false
        payload = nil
        OauthAuthorization.transaction do
          stored.lock!
          stored.reload
          authorization.reload
          if stored.used?
            reused = true
            raise ActiveRecord::Rollback
          end
          unless authorization.active?
            inactive = true
            raise ActiveRecord::Rollback
          end

          stored.mark_used!
          payload = issue_token_pair!(authorization)
        end
        if reused
          VoidOauthAuthorization.call(authorization: authorization)
          return oauth_failure("invalid_grant", "authorization code has already been used")
        end
        return oauth_failure("invalid_grant", "authorization is inactive") if inactive || payload.nil?

        success(payload)
      end

      def issue_refresh_token
        client_result = authenticate_client
        return client_result if client_result.failure?

        client = client_result.value
        return oauth_failure("invalid_request", "refresh_token is required") if refresh_token.blank?
        return oauth_failure("invalid_grant", "refresh token is invalid") unless RefreshToken.valid_format?(refresh_token)

        stored = RefreshToken.find_by_token(OauthRefreshToken, refresh_token)
        return oauth_failure("invalid_grant", "refresh token is invalid") if stored.nil?
        return oauth_failure("invalid_grant", "refresh token is invalid") unless stored.oauth_authorization.oauth_client_id == client.id
        return oauth_failure("invalid_grant", "refresh token is expired") if stored.expired?

        authorization = stored.oauth_authorization
        if stored.revoked?
          VoidOauthAuthorization.call(authorization: authorization)
          return oauth_failure("invalid_grant", "refresh token is revoked")
        end
        return oauth_failure("invalid_grant", "authorization is inactive") unless authorization.active?

        reused = false
        inactive = false
        payload = nil
        OauthRefreshToken.transaction do
          stored.lock!
          stored.reload
          authorization.reload
          if stored.revoked?
            reused = true
            raise ActiveRecord::Rollback
          end
          unless authorization.active?
            inactive = true
            raise ActiveRecord::Rollback
          end

          stored.revoke!
          payload = issue_token_pair!(authorization, replaced_refresh: stored)
        end
        if reused
          VoidOauthAuthorization.call(authorization: authorization)
          return oauth_failure("invalid_grant", "refresh token is revoked")
        end
        return oauth_failure("invalid_grant", "authorization is inactive") if inactive || payload.nil?

        success(payload)
      end

      def authenticate_client
        result = AuthenticateOauthClient.call(client_id: client_id, client_secret: client_secret, api: api_key)
        return result if result.success?

        oauth_failure("invalid_client", "client authentication failed")
      end

      def verify_pkce(client:, stored:)
        if client.public?
          return oauth_failure("invalid_request", "code_verifier is required") if code_verifier.blank?
          return oauth_failure("invalid_grant", "PKCE verification failed") unless Pkce.s256_matches?(code_verifier, stored.code_challenge)
        elsif stored.code_challenge.present?
          return oauth_failure("invalid_grant", "PKCE verification failed") unless Pkce.s256_matches?(code_verifier, stored.code_challenge)
        end

        true
      end

      def issue_token_pair!(authorization, replaced_refresh: nil)
        access_data = AccessToken.generate
        refresh_data = RefreshToken.generate
        now = Time.current
        access = OauthAccessToken.create!(
          oauth_authorization: authorization,
          token_digest: access_data.fetch(:digest),
          token_prefix: access_data.fetch(:prefix),
          expires_at: now + access_token_ttl
        )
        refresh = OauthRefreshToken.create!(
          oauth_authorization: authorization,
          token_digest: refresh_data.fetch(:digest),
          token_prefix: refresh_data.fetch(:prefix),
          expires_at: now + refresh_token_ttl
        )
        replaced_refresh&.update_columns(replaced_by_id: refresh.id, updated_at: now)

        {
          access_token: access_data.fetch(:token),
          token_type: "Bearer",
          expires_in: (access.expires_at - now).to_i,
          refresh_token: refresh_data.fetch(:token),
          created_at: access.created_at.to_i,
          oauth_authorization_id: authorization.id
        }
      end

      def oauth_failure(code, description)
        failure({ error: code, error_description: description })
      end

      def access_token_ttl
        RecordingStudioOauth.configuration.access_token_ttl.presence || 1.hour
      end

      def refresh_token_ttl
        RecordingStudioOauth.configuration.refresh_token_ttl.presence || 30.days
      end

      def service_args
        { grant_type: grant_type, api_key: api_key, client_id_present: client_id.present? }
      end
    end
  end
end
