# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class RefreshOutboundConnection < RecordingStudio::Services::BaseService
      PERMANENT_ERRORS = %w[invalid_grant invalid_client unauthorized_client].freeze
      PERMANENT_STATUSES = [400, 401].freeze

      def initialize(connection:, at: nil)
        @connection = connection
        @at = at
      end

      private

      attr_reader :connection

      def perform
        return success(nil) if connection.nil?
        return success(nil) if connection.revoked?
        return success(connection) if connection.active? && !connection.expired?(at: time)

        @attempt_refresh_token = connection.refresh_token
        @attempt_status = connection.status

        return mark_reconnect if connection.refresh_token.blank?

        provider = Outbound.provider(connection.provider_key)
        return mark_reconnect if provider.nil? || !provider.refresh?

        token = Outbound::TokenClient.new(provider).refresh(refresh_token: @attempt_refresh_token)
        return refresh_failure(token) unless token.ok?
        return mark_reconnect if token.body["access_token"].to_s.blank?

        apply_token!(token.body)
        return success(nil) if connection.revoked?

        success(connection)
      rescue ActiveRecord::ActiveRecordError
        failure(:save_failed)
      end

      def refresh_failure(token)
        return mark_reconnect if permanent_oauth_failure?(token)

        failure(:transient)
      end

      def permanent_oauth_failure?(token)
        return false unless PERMANENT_STATUSES.include?(token.status)

        PERMANENT_ERRORS.include?(token.body["error"].to_s)
      end

      def apply_token!(body)
        updates = {
          access_token: body["access_token"].to_s,
          status: "active",
          expires_at: expires_at_from(body)
        }
        updates[:refresh_token] = body["refresh_token"].to_s if body["refresh_token"].present?
        updates[:granted_scopes] = body["scope"].to_s.split(/\s+/).reject(&:blank?) if body["scope"].present?
        connection.with_lock do
          connection.reload
          next if stale_write?

          connection.update!(updates)
        end
      end

      def mark_reconnect
        connection.with_lock do
          connection.reload
          unless stale_write? || connection.needs_reconnect?
            connection.update_columns(status: "needs_reconnect", updated_at: Time.current)
          end
        end
        connection.reload
        success(nil)
      end

      def stale_write?
        connection.revoked? ||
          connection.status != @attempt_status ||
          connection.refresh_token != @attempt_refresh_token
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
