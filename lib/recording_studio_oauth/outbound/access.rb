# frozen_string_literal: true

module RecordingStudioOauth
  module Outbound
    module Access
      module_function

      def may_manage_root?(actor:, root:)
        return false if actor.nil? || root.nil?

        RecordingStudioAccessible.authorized?(actor: actor, recording: root, role: :admin)
      end

      def may_use_root?(actor:, root:)
        return false if actor.nil? || root.nil?

        RecordingStudioAccessible.authorized?(actor: actor, recording: root, role: :view)
      end

      def owned_by_actor?(connection, actor)
        return false if actor.nil? || connection.nil?
        return false if connection.owner_actor_id.blank?

        connection.owner_actor_type == actor.class.name && connection.owner_actor_id.to_s == actor.id.to_s
      end

      def connected_by?(connection, actor)
        return false if actor.nil? || connection.nil?
        return false if connection.connected_by_id.blank?

        connection.connected_by_type == actor.class.name && connection.connected_by_id.to_s == actor.id.to_s
      end

      def shared_root?(root)
        return false if root.nil?
        return false unless RecordingStudio.respond_to?(:shared_root?)

        RecordingStudio.shared_root?(root)
      end
    end
  end
end
