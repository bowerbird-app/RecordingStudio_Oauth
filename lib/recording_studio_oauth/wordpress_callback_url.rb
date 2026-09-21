# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  class WordPressCallbackUrl
    ACTION = "recording_studio_oauth_callback"
    MAX_LENGTH = 2048
    PATH_LEAF = %w[wp-admin admin-post.php].freeze
    SEGMENT = /\A[A-Za-z0-9._~-]+\z/
    DOT_SEGMENTS = %w[. ..].freeze

    def self.parse(raw)
      value = raw.to_s
      return unless plausible?(value)

      uri = parse_http_uri(value)
      return unless allowed_uri?(uri) && allowed_path?(uri.path) && allowed_query?(uri.query)

      new(canonical(uri))
    end

    def self.plausible?(value)
      value.present? && value.bytesize <= MAX_LENGTH
    end
    private_class_method :plausible?

    def self.parse_http_uri(value)
      uri = URI.parse(value)
      uri if uri.is_a?(URI::HTTP)
    rescue URI::InvalidURIError
      nil
    end
    private_class_method :parse_http_uri

    def self.allowed_uri?(uri)
      return false if uri.nil?
      return false if uri.userinfo.present? || uri.fragment.present?

      uri.host.present? && uri.query.present?
    end
    private_class_method :allowed_uri?

    def self.allowed_path?(path)
      segments = path.to_s.split("/").reject(&:empty?)
      return false if segments.length < 2
      return false unless segments.last(2) == PATH_LEAF
      return false if segments.intersect?(DOT_SEGMENTS)

      segments[0..-3].all? { |segment| SEGMENT.match?(segment) }
    end
    private_class_method :allowed_path?

    def self.allowed_query?(query)
      URI.decode_www_form(query.to_s) == [["action", ACTION]]
    end
    private_class_method :allowed_query?

    def self.canonical(uri)
      host = uri.host.to_s.downcase
      port = uri.port
      omit_port = (uri.scheme == "http" && port == 80) || (uri.scheme == "https" && port == 443)
      authority = omit_port ? host : "#{host}:#{port}"
      "#{uri.scheme}://#{authority}#{uri.path}?action=#{ACTION}"
    end
    private_class_method :canonical

    def initialize(canonical_url)
      @canonical_url = canonical_url
    end

    def to_s
      @canonical_url
    end
  end
end
