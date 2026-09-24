# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  class SessionToken
    SHOPIFY_PROVIDER = "shopify"

    attr_reader :claims, :provider, :external_id

    def initialize(claims:, provider:)
      @claims = claims
      @provider = provider.to_s.strip.downcase
      @external_id = extract_external_id
    end

    def shopify?
      provider == SHOPIFY_PROVIDER
    end

    def dest_host
      host_for(claims["dest"])
    end

    def iss_host
      host_for(claims["iss"])
    end

    def shopify_hosts_match?
      dest_host.present? && dest_host == iss_host
    end

    def matches_external_id?(expected)
      return true if expected.blank?

      wanted = normalize_id(expected)
      wanted == external_id || host_for(expected) == external_id
    end

    private

    def extract_external_id
      host = dest_host
      return host if host.present?

      normalize_id(claims["sub"])
    end

    def host_for(value)
      return if value.blank?

      text = value.to_s
      uri = URI.parse(text)
      host = uri.host.presence || URI.parse("https://#{text}").host
      normalize_id(host)
    rescue URI::InvalidURIError
      nil
    end

    def normalize_id(value)
      value.to_s.strip.downcase.presence
    end
  end
end
