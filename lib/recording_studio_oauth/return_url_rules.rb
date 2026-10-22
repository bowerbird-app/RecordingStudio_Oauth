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

    def safe_relative_path(value)
      raw = value.to_s
      return unless relative_path_shape?(raw)

      uri = URI.parse(raw)
      return if uri.scheme.present? || uri.host.present? || uri.userinfo.present?

      raw
    rescue URI::InvalidURIError
      nil
    end

    def relative_path_shape?(raw)
      return false if raw.blank? || raw.bytesize > MAX_LENGTH
      return false if raw.match?(/[[:cntrl:]]/) || raw.match?(/\s/)
      return false if raw.include?("\\") || raw.include?("://")

      raw.start_with?("/") && !raw.start_with?("//")
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
