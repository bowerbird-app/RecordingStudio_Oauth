# frozen_string_literal: true

require "uri"
require "recording_studio_oauth/return_url_rules"

module RecordingStudioOauth
  module Outbound
    module HttpsUrl
      module_function

      def assert_endpoints!(options)
        assert!(:authorize_url, options[:authorize_url], options)
        assert!(:token_url, options[:token_url], options)
        return if options[:revoke_url].to_s.strip.blank?

        assert!(:revoke_url, options[:revoke_url], options)
      end

      def assert!(name, value, options = {})
        return if relative_path?(value)
        return if name != :authorize_url && options[:http].respond_to?(:call)

        uri = URI.parse(value.to_s)
        return if uri.scheme == "https" && uri.host.present?

        raise ArgumentError, "#{name} must be https"
      rescue URI::InvalidURIError
        raise ArgumentError, "#{name} must be https"
      end

      def relative_path?(value)
        raw = value.to_s
        return false unless ReturnUrlRules.relative_path_shape?(raw)

        uri = URI.parse(raw)
        uri.scheme.blank? && uri.host.blank?
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
