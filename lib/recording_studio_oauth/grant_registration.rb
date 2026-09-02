# frozen_string_literal: true

module RecordingStudioOauth
  module GrantRegistration
    module_function

    def register!
      return unless defined?(RecordingStudioApi)
      return unless RecordingStudioApi.respond_to?(:register_oauth_grant)

      RecordingStudioApi.register_oauth_grant(
        "authorization_code",
        handler: RecordingStudioOauth::Services::IssueDelegatedAccessToken
      )
      RecordingStudioApi.register_oauth_grant(
        "refresh_token",
        handler: RecordingStudioOauth::Services::IssueDelegatedAccessToken
      )
    end
  end
end
