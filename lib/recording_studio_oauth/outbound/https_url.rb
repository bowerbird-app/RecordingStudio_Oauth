# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  module Outbound
    module HttpsUrl
      module_function

      def assert_endpoints!(options)
        return if options[:http]

        assert!(:authorize_url, options[:authorize_url])
        assert!(:token_url, options[:token_url])
        return if options[:revoke_url].to_s.strip.blank?

        assert!(:revoke_url, options[:revoke_url])
      end

      def assert!(name, value)
        uri = URI.parse(value.to_s)
        return if uri.scheme == "https" && uri.host.present?

        raise ArgumentError, "#{name} must be https"
      rescue URI::InvalidURIError
        raise ArgumentError, "#{name} must be https"
      end
    end
  end
end
