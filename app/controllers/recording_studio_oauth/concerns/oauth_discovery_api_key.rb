# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module OauthDiscoveryApiKey
      extend ActiveSupport::Concern

      private

      def current_api_key
        api_key_from_issuer_path.presence || api_key_from_resource_path.presence || params[:api_key].to_s.presence || "public"
      end

      def inserted_issuer_path
        suffix = params[:issuer_path].to_s.delete_prefix("/")
        return if suffix.empty?

        "/#{suffix}"
      end

      def configured_mount_path
        RecordingStudioOauth.configuration.engine_mount_path.presence || "/recording_studio_oauth"
      end

      def known_issuer_path?
        path = issuer_path
        return true if path == configured_mount_path

        path.match?(%r{\A#{Regexp.escape(configured_mount_path)}/apis/[^/]+\z})
      end

      def api_key_from_issuer_path
        path = inserted_issuer_path
        return unless path

        match = path.match(%r{\A#{Regexp.escape(configured_mount_path)}/apis/([^/]+)\z})
        match && match[1]
      end

      def api_key_from_resource_path
        suffix = "/#{params[:resource_path].to_s.delete_prefix('/')}"
        return if suffix == "/"

        [configured_api_mount_path, configured_mcp_mount_path].each do |mount|
          match = suffix.match(%r{\A#{Regexp.escape(mount)}/apis/([^/]+)\z})
          return match[1] if match
        end
        nil
      end

      def configured_api_mount_path
        RecordingStudioOauth.configuration.api_mount_path.presence || "/recording_studio_api"
      end

      def configured_mcp_mount_path
        RecordingStudioOauth.configuration.mcp_mount_path.presence || "/recording_studio_mcp"
      end
    end
  end
end
