# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class LookupOutboundConnection < RecordingStudio::Services::BaseService
      def initialize(provider:, root:, actor:)
        @provider_key = provider.to_s
        @root = root
        @actor = actor
      end

      private

      attr_reader :provider_key, :root, :actor

      def perform
        return success(nil) if actor.nil? || provider_key.blank?

        success(pick_user_connection || pick_root_connection)
      end

      def pick_user_connection
        row = Outbound::LiveConnection.user_owned(provider_key: provider_key, actor: actor, root: root)
        return if row.nil? || row.revoked? || row.needs_reconnect?

        usable_after_refresh(row)
      end

      def pick_root_connection
        row = Outbound::LiveConnection.root_owned(provider_key: provider_key, root: root, actor: actor)
        return if row.nil? || row.revoked? || row.needs_reconnect?

        usable_after_refresh(row)
      end

      def usable_after_refresh(row)
        return row if row.usable?

        result = RefreshOutboundConnection.call(connection: row)
        return result.value if result.success?

        nil
      end

      def service_args
        { provider: provider_key }
      end
    end
  end
end
