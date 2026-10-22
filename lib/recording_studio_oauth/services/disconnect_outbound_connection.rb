# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class DisconnectOutboundConnection < RecordingStudio::Services::BaseService
      def initialize(connection:, actor:)
        @connection = connection
        @actor = actor
      end

      private

      attr_reader :connection, :actor

      def perform
        return failure(:not_found) if connection.nil?
        return failure(:unauthenticated) if actor.nil?
        return failure(:forbidden) unless may_disconnect?
        return success(connection) if connection.revoked?

        revoke_at_provider
        connection.update!(
          status: "revoked",
          access_token: "revoked",
          refresh_token: nil
        )
        success(connection)
      rescue ActiveRecord::ActiveRecordError
        failure(:save_failed)
      end

      def may_disconnect?
        if connection.root_owned?
          Outbound::Access.may_manage_root?(actor: actor, root: connection.root_recording)
        else
          Outbound::Access.owned_by_actor?(connection, actor)
        end
      end

      def revoke_at_provider
        provider = Outbound.provider(connection.provider_key)
        return if provider.nil? || !provider.revoke?

        token = connection.access_token.presence || connection.refresh_token
        return if token.blank?

        Outbound::TokenClient.new(provider).revoke(token: token)
      end

      def service_args
        { connection_id: connection&.id }
      end
    end
  end
end
