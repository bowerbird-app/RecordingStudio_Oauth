# frozen_string_literal: true

class FakeOauth
  CLIENT_ID = "dummy-fake-drive"
  CLIENT_SECRET = "dummy-fake-drive-secret"
  FAIL_REFRESH = "fail-refresh"

  class << self
    def call(url, params)
      if url.to_s.include?("revoke")
        [200, {}]
      elsif params["grant_type"] == "refresh_token"
        refresh(params)
      else
        redeem(params)
      end
    end

    def issue_code(access_token:, refresh_token:, user_id:, email:, expires_in: 3600, scope: "files.read")
      verifier.generate(
        {
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "user_id" => user_id,
          "email" => email,
          "expires_in" => expires_in,
          "scope" => scope
        },
        expires_in: 10.minutes
      )
    end

    def valid_client?(client_id)
      client_id.to_s == CLIENT_ID
    end

    private

    def redeem(params)
      return [401, { "error" => "invalid_client" }] unless credentials_match?(params)

      payload = verifier.verified(params["code"].to_s)
      return [400, { "error" => "invalid_grant" }] if payload.blank?

      [200, payload]
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      [400, { "error" => "invalid_grant" }]
    end

    def refresh(params)
      return [401, { "error" => "invalid_client" }] unless credentials_match?(params)
      return [400, { "error" => "invalid_grant" }] if params["refresh_token"].to_s == FAIL_REFRESH

      [
        200,
        {
          "access_token" => "refreshed-access-#{SecureRandom.hex(8)}",
          "refresh_token" => params["refresh_token"].to_s,
          "expires_in" => 3600,
          "scope" => "files.read"
        }
      ]
    end

    def credentials_match?(params)
      params["client_id"].to_s == CLIENT_ID && params["client_secret"].to_s == CLIENT_SECRET
    end

    def verifier
      ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, digest: "SHA256", serializer: JSON)
    end
  end
end
