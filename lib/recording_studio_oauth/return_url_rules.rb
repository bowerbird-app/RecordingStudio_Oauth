# frozen_string_literal: true

require "uri"
require_relative "return_url_pattern"

module RecordingStudioOauth
  module ReturnUrlRules
    MAX_LENGTH = 2048
    UNSAFE_RELATIVE = %r{[[:cntrl:]]|\s|\\|://}

    module_function

    def allow?(return_to, patterns:, exact_urls:)
      url = safe_http_url(return_to)
      return false if url.nil?

      return true if Array(exact_urls).any? { |exact| exact.to_s == url }

      candidate = http_uri(url)
      return false if candidate.nil?

      Array(patterns).any? { |pattern| pattern_match?(pattern.to_s, candidate) }
    end

    def any_host_pattern?(pattern)
      parsed, error = ReturnUrlPattern.parse(pattern.to_s)
      error.nil? && parsed.any_host?
    end

    def pattern_error(pattern)
      return "must be text" unless pattern.is_a?(String)

      _parsed, error = ReturnUrlPattern.parse(pattern)
      error
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
      return false unless raw.present? && raw.bytesize <= MAX_LENGTH
      return false if raw.match?(UNSAFE_RELATIVE)

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
      host = uri.host.to_s
      uri.userinfo.present? || uri.fragment.present? || host.blank? || host.end_with?(".") || host.include?("%")
    end

    def pattern_match?(pattern, candidate)
      parsed, error = ReturnUrlPattern.parse(pattern)
      return false unless error.nil?

      parsed.match?(candidate)
    end
  end
end
