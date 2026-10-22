# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class RefreshOutboundConnection < RecordingStudio::Services::BaseService
      def initialize(connection:, at: nil)
        @connection = connection
        @at = at
      end

      private

      attr_reader :connection

      def perform
        return success(nil) if connection.nil?
        return success(nil) if connection.revoked?

        connection.with_lock do
          connection.reload
          return success(connection) if connection.active? && !connection.expired?(at: time)
          return mark_reconnect if connection.refresh_token.blank?

          provider = Outbound.provider(connection.provider_key)
          return mark_reconnect if provider.nil? || !provider.refresh?

          token = Outbound::TokenClient.new(provider).refresh(refresh_token: connection.refresh_token)
          return mark_reconnect unless token.ok?
          return mark_reconnect if token.body["access_token"].to_s.blank?

          updates = {
            access_token: token.body["access_token"].to_s,
            status: "active",
            expires_at: expires_at_from(token.body)
          }
          updates[:refresh_token] = token.body["refresh_token"].to_s if token.body["refresh_token"].present?
          updates[:granted_scopes] = token.body["scope"].to_s.split(/\s+/).reject(&:blank?) if token.body["scope"].present?
          connection.update!(updates)
        end

        success(connection)
      rescue ActiveRecord::ActiveRecordError
        mark_reconnect_without_raise
      end

      def mark_reconnect
        connection.update_columns(status: "needs_reconnect", updated_at: Time.current) unless connection.needs_reconnect?
        connection.reload
        success(nil)
      end

      def mark_reconnect_without_raise
        return success(nil) if connection.nil?

        mark_reconnect
      rescue ActiveRecord::ActiveRecordError
        success(nil)
      end

      def expires_at_from(body)
        seconds = body["expires_in"]
        return if seconds.blank?

        Time.current + seconds.to_i.seconds
      end

      def time
        @at || Time.current
      end

      def service_args
        { connection_id: connection&.id }
      end
    end
  end
end
