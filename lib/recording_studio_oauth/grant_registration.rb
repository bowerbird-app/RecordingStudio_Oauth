# frozen_string_literal: true

module RecordingStudioOauth
  module GrantRegistration
    module_function

    def register!
      RecordingStudioApi.register_oauth_grant("authorization_code", handler: DelegatedGrant)
      RecordingStudioApi.register_oauth_grant("refresh_token", handler: DelegatedGrant)
    end
  end

  class DelegatedGrant
    TOKEN_KEYS = %w[code redirect_uri code_verifier refresh_token resource].freeze

    def self.call(grant_type:, params:, client_id:, client_secret:, api:)
      request = request_hash(params)
      Services::IssueDelegatedAccessToken.call(
        grant_type: grant_type,
        client_id: client_id,
        client_secret: client_secret,
        api: api,
        **request.slice(*TOKEN_KEYS).symbolize_keys
      )
    end

    def self.request_hash(params)
      return {} if params.blank?

      hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      hash.stringify_keys
    end
    private_class_method :request_hash
  end
end
