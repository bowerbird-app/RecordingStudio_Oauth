# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  module RedirectUriRules
    LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze
    MAX_LENGTH = 2048
    HTTPS_OR_LOOPBACK = "redirect URIs must be https, or http on localhost, 127.0.0.1, or [::1]"

    module_function

    def self_registered_error(uris)
      list = Array(uris)
      return "redirect_uris is required" if list.empty?

      list.each do |uri|
        error = self_registered_uri_error(uri)
        return error if error
      end

      nil
    end

    def self_registered_uri_error(uri)
      return "redirect URIs must be text" unless uri.is_a?(String)

      raw = uri.to_s
      return "redirect URIs must not be blank" if raw.strip.empty?
      return "redirect URIs must be #{MAX_LENGTH} characters or fewer" if raw.bytesize > MAX_LENGTH

      parsed = parse_http(raw)
      parsed ? parsed_uri_error(parsed) : "redirect URIs must be valid URIs"
    end

    def parsed_uri_error(parsed)
      return "redirect URIs must not include a fragment" if parsed.fragment.present?
      return "redirect URIs must not include user info" if parsed.userinfo.present?
      return "redirect URIs must have a host" if parsed.host.blank?
      return "redirect URIs must not use a wildcard host" if wildcard_host?(parsed.host)
      return HTTPS_OR_LOOPBACK unless https_or_loopback?(parsed)

      nil
    end

    def https_or_loopback?(parsed)
      parsed.is_a?(URI::HTTPS) || (parsed.is_a?(URI::HTTP) && loopback_host?(parsed.host))
    end

    def parse_http(raw)
      parsed = URI.parse(raw)
      parsed if parsed.is_a?(URI::HTTP)
    rescue URI::InvalidURIError
      nil
    end

    def wildcard_host?(host)
      host.to_s.include?("*")
    end

    def loopback_host?(host)
      LOOPBACK_HOSTS.include?(host.to_s.downcase.delete_prefix("[").delete_suffix("]"))
    end
  end
end
