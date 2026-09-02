# frozen_string_literal: true

require "securerandom"
require_relative "token_digest"

module RecordingStudioOauth
  module AuthorizationCode
    PREFIX = "rsoauth_ac"
    TOKEN_PATTERN = /\A#{PREFIX}_[A-Za-z0-9\-_]+\z/

    module_function

    def generate
      token = "#{PREFIX}_#{SecureRandom.urlsafe_base64(32)}"

      {
        token: token,
        digest: TokenDigest.digest(token)
      }
    end

    def valid_format?(token)
      TOKEN_PATTERN.match?(token.to_s)
    end

    def find_by_token(scope, token)
      TokenDigest.find_by_digest(scope, :code_digest, token)
    end
  end
end
