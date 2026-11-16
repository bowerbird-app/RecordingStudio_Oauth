# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    module HookSecretCatalog
      FILTERED = "[FILTERED]"
      SECRET_KEYS = %w[
        token
        access_token
        refresh_token
        client_secret
        code
        code_verifier
        id_token
        password
        assertion
        client_assertion
        device_code
        user_code
        authorization_code
        session_token_secret
        state_secret
        secret
        nonce
        state
      ].freeze
      PARAM_KEYS = %w[
        grant_type
        client_id
        redirect_uri
        scope
        resource
        token_type_hint
        response_type
        code_challenge
        code_challenge_method
      ].freeze
      SECRET_IVARS = %i[
        @client_secret
        @session_token_secret
        @state_secret
        @code
        @code_verifier
        @refresh_token
        @token
        @secret
        @attempt_refresh_token
        @authorization_header
        @state
        @site_state
      ].freeze
      SECRET_COLUMNS = %w[
        access_token
        refresh_token
        code_verifier
        session_token_secret_ciphertext
      ].freeze
      SECRET_RECORD_READERS = {
        "RecordingStudioOauth::OutboundConnection" => %i[access_token refresh_token],
        "RecordingStudioOauth::OutboundHandshake" => %i[code_verifier nonce],
        "RecordingStudioOauth::OauthClient" => %i[session_token_secret]
      }.freeze
      TOKEN_RECORD_NAMES = %w[
        RecordingStudioOauth::OauthAccessToken
        RecordingStudioOauth::OauthRefreshToken
        RecordingStudioOauth::OauthAuthorizationCode
      ].freeze
      SECRET_ASSOCIATIONS = {
        "RecordingStudioOauth::OauthAuthorization" => {
          belongs: %i[oauth_client],
          collections: %i[access_tokens refresh_tokens authorization_codes]
        },
        "RecordingStudioOauth::OauthClient" => {
          belongs: [],
          collections: %i[authorizations external_installs]
        },
        "RecordingStudioOauth::ExternalInstall" => {
          belongs: %i[oauth_client],
          collections: []
        }
      }.freeze
    end
  end
end
