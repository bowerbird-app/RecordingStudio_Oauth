# frozen_string_literal: true

module RecordingStudioOauth
  class OauthClient < ApplicationRecord
    self.table_name = "recording_studio_oauth_clients"

    has_many :authorizations,
             class_name: "RecordingStudioOauth::OauthAuthorization",
             dependent: :destroy,
             inverse_of: :oauth_client

    before_validation :assign_client_id, on: :create

    validates :name, presence: true
    validates :client_id, presence: true, uniqueness: true
    validates :api_key, presence: true, inclusion: { in: ->(_) { RecordingStudioOauth::Integration.api_names } }
    validates :redirect_uris, presence: true
    validate :redirect_uris_must_be_absolute
    validate :return_lists_are_strings
    validate :exact_return_urls_must_be_absolute
    validate :allowed_return_patterns_must_be_short
    validate :central_relay_has_a_return_rule
    validate :confidential_clients_require_secret_digest
    validate :api_key_must_not_change, on: :update

    scope :active, -> { where(revoked_at: nil) }

    def public?
      !confidential?
    end

    def registered_for_api?(request_api)
      request_key = request_api.to_s
      return true if public? && api_key == "public"

      api_key == request_key
    end

    def revoked?
      revoked_at.present?
    end

    def active?
      !revoked?
    end

    def redirect_uri_allowed?(uri)
      normalized = uri.to_s
      Array(redirect_uris).any? { |allowed| allowed.to_s == normalized }
    end

    def allows_return_to?(return_to)
      return false unless use_central_relay?

      ReturnUrlRules.allow?(
        return_to,
        patterns: allowed_return_patterns,
        exact_urls: exact_return_urls
      )
    end

    def authenticate_secret?(secret)
      return false if public?
      return false if client_secret_digest.blank? || secret.blank?

      TokenDigest.matches?(client_secret_digest, secret)
    end

    def revoke!(time: Time.current)
      update!(revoked_at: time) if revoked_at.nil?
    end

    private

    def assign_client_id
      self.client_id = OauthClientSecret.generate_client_id if client_id.blank?
    end

    def redirect_uris_must_be_absolute
      each_absolute_http(:redirect_uris, allow_userinfo: true)
    end

    def return_lists_are_strings
      %i[allowed_return_patterns exact_return_urls].each do |attribute|
        list = public_send(attribute)
        next if list.is_a?(Array) && list.all? { |item| item.is_a?(String) }

        errors.add(attribute, "must be a list of text lines")
      end
    end

    def exact_return_urls_must_be_absolute
      each_absolute_http(:exact_return_urls, allow_userinfo: false)
    end

    def allowed_return_patterns_must_be_short
      Array(allowed_return_patterns).each do |pattern|
        next if pattern.to_s.bytesize <= ReturnUrlRules::MAX_LENGTH

        errors.add(:allowed_return_patterns, "must be #{ReturnUrlRules::MAX_LENGTH} characters or fewer")
        break
      end
    end

    def central_relay_has_a_return_rule
      return unless use_central_relay?
      return if Array(allowed_return_patterns).any? || Array(exact_return_urls).any?

      errors.add(:use_central_relay, "needs a return pattern or an exact URL")
    end

    def each_absolute_http(attribute, allow_userinfo:)
      Array(public_send(attribute)).each do |uri|
        next if absolute_http?(uri, allow_userinfo: allow_userinfo)

        errors.add(attribute, absolute_http_error(uri))
        break
      end
    end

    def absolute_http?(uri, allow_userinfo:)
      parsed = URI.parse(uri.to_s)
      parsed.is_a?(URI::HTTP) && parsed.host.present? && parsed.fragment.nil? && allowed_userinfo?(parsed, allow_userinfo)
    rescue URI::InvalidURIError
      false
    end

    def allowed_userinfo?(parsed, allow_userinfo)
      allow_userinfo || parsed.userinfo.nil?
    end

    def absolute_http_error(uri)
      URI.parse(uri.to_s)
      "must be absolute HTTP(S) URIs without fragments"
    rescue URI::InvalidURIError
      "must be valid URIs"
    end

    def confidential_clients_require_secret_digest
      return unless confidential?
      return if client_secret_digest.present?

      errors.add(:client_secret_digest, "is required for confidential clients")
    end

    def api_key_must_not_change
      errors.add(:api_key, "cannot be changed") if will_save_change_to_api_key?
    end
  end
end
