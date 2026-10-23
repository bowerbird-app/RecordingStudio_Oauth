# frozen_string_literal: true

module RecordingStudioOauth
  module Outbound
    module LiveConnection
      module_function

      def find(provider:, root:, actor:)
        provider_key = provider.to_s
        return if actor.nil? || provider_key.blank?

        user_owned(provider_key: provider_key, actor: actor, root: root) ||
          root_owned(provider_key: provider_key, root: root, actor: actor)
      end

      def user_owned(provider_key:, actor:, root:)
        return if actor.nil? || root.nil?

        OutboundConnection.live.for_provider(provider_key).find_by(
          owner_actor_type: actor.class.name,
          owner_actor_id: actor.id,
          root_recording_id: root.id
        )
      end

      def root_owned(provider_key:, root:, actor:)
        return unless Access.may_use_root?(actor: actor, root: root)

        OutboundConnection.live.for_provider(provider_key).find_by(
          root_recording_id: root.id,
          owner_actor_id: nil
        )
      end
    end
  end
end
