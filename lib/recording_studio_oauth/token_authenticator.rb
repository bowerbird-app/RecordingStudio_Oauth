# frozen_string_literal: true

module RecordingStudioOauth
  class TokenAuthenticator
    def self.register!
      return unless defined?(RecordingStudioApi)
      return unless RecordingStudioApi.respond_to?(:register_token_authenticator)
      return if RecordingStudioApi.token_authenticators.include?(self)

      RecordingStudioApi.register_token_authenticator(self)
    end

    def self.valid_format?(token)
      AccessToken.valid_format?(token)
    end

    def self.call(token:)
      return unless valid_format?(token)

      stored = AccessToken.find_by_token(
        OauthAccessToken.includes(oauth_authorization: %i[oauth_client access_recording]),
        token
      )
      return if stored.nil?

      { credential: stored, token_record: stored }
    end
  end
end
