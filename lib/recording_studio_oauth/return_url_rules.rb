# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  module ReturnUrlRules
    MAX_LENGTH = 2048

    module_function

    def allow?(return_to, patterns:, exact_urls:)
      url = safe_http_url(return_to)
      return false if url.nil?

      return true if Array(exact_urls).any? { |exact| exact.to_s == url }

      Array(patterns).any? { |pattern| glob_match?(pattern.to_s, url) }
    end

    def safe_http_url(value)
      raw = value.to_s
      return if raw.blank? || raw.bytesize > MAX_LENGTH

      uri = http_uri(raw)
      return if uri.nil? || unsafe_http?(uri)

      raw
    end

    def http_uri(raw)
      uri = URI.parse(raw)
      uri if uri.is_a?(URI::HTTP)
    rescue URI::InvalidURIError
      nil
    end

    def unsafe_http?(uri)
      uri.userinfo.present? || uri.fragment.present? || uri.host.blank?
    end

    def glob_match?(pattern, url)
      return false if pattern.blank? || pattern.bytesize > MAX_LENGTH

      body = pattern.split("*", -1).map { |part| Regexp.escape(part) }.join(".*")
      Regexp.new("\\A#{body}\\z").match?(url)
    end
  end
end
