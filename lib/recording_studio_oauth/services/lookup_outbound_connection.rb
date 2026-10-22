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

        connection = actor_connection || root_connection
        return success(nil) if connection.nil?
        return success(nil) if connection.revoked? || connection.needs_reconnect?

        if connection.expired? || !connection.active?
          connection = RefreshOutboundConnection.call(connection: connection).value
        end

        success(connection)
      end

      def actor_connection
        OutboundConnection.usable.for_provider(provider_key).find_by(
          owner_actor_type: actor.class.name,
          owner_actor_id: actor.id
        ) || OutboundConnection.live.for_provider(provider_key).find_by(
          owner_actor_type: actor.class.name,
          owner_actor_id: actor.id
        )
      end

      def root_connection
        return if root.nil?
        return unless Outbound::Access.may_use_root?(actor: actor, root: root)

        found = OutboundConnection.usable.for_provider(provider_key).find_by(root_recording_id: root.id)
        found || OutboundConnection.live.for_provider(provider_key).find_by(root_recording_id: root.id)
      end

      def service_args
        { provider: provider_key }
      end
    end
  end
end
