# frozen_string_literal: true

require "securerandom"
require_relative "token_digest"

module RecordingStudioOauth
  module OauthClientSecret
    PREFIX = "rsoauth_cs"

    module_function

    def generate
      token = "#{PREFIX}_#{SecureRandom.urlsafe_base64(32)}"

      {
        token: token,
        digest: TokenDigest.digest(token)
      }
    end

    def generate_client_id
      "rsoauth_oc_#{SecureRandom.hex(16)}"
    end
  end
end
