# frozen_string_literal: true

require "active_support/message_verifier"
require "json"

module RecordingStudioOauth
  class CentralRelayState
    PURPOSE = "recording_studio_oauth.central_relay"

    attr_reader :return_to, :site_state, :client_id, :code_challenge

    def initialize(return_to:, client_id:, code_challenge:, site_state: nil)
      @return_to = return_to.to_s
      @client_id = client_id.to_s
      @code_challenge = code_challenge.to_s
      @site_state = site_state.to_s
    end

    def sign(secret: nil, expires_in: nil)
      ttl = expires_in || RecordingStudioOauth.configuration.authorization_code_ttl || 10.minutes
      verifier(secret).generate(payload, purpose: PURPOSE, expires_in: ttl)
    end

    def self.parse(token, secret: nil)
      data = verified_payload(token, secret)
      return if data.blank?

      from_payload(data)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def self.verified_payload(token, secret)
      payload = signing_verifier(secret).verified(token.to_s, purpose: PURPOSE)
      payload.is_a?(Hash) ? payload : nil
    end
    private_class_method :verified_payload

    def self.from_payload(data)
      return_to = data["return_to"].to_s
      return if ReturnUrlRules.safe_http_url(return_to).nil?
      return if data["client_id"].to_s.blank? || data["code_challenge"].to_s.blank?

      new(
        return_to: return_to,
        client_id: data["client_id"],
        code_challenge: data["code_challenge"],
        site_state: data["site_state"]
      )
    end
    private_class_method :from_payload

    def self.signing_verifier(secret = nil)
      key = secret.to_s.presence || default_secret
      ActiveSupport::MessageVerifier.new(key, digest: "SHA256", serializer: JSON)
    end

    def self.default_secret
      raise "secret_key_base is required to sign central relay state" unless rails_secret?

      Rails.application.secret_key_base.to_s
    end

    def self.rails_secret?
      defined?(Rails) && Rails.application&.secret_key_base.present?
    end
    private_class_method :rails_secret?
    private_class_method :default_secret

    private

    def verifier(secret)
      self.class.signing_verifier(secret)
    end

    def payload
      {
        "return_to" => return_to,
        "client_id" => client_id,
        "code_challenge" => code_challenge,
        "site_state" => site_state
      }
    end
  end
end
