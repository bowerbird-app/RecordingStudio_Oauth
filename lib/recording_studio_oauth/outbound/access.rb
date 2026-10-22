# frozen_string_literal: true

module RecordingStudioOauth
  module Outbound
    module Access
      module_function

      def root_access_error(actor:, root:, role:)
        return :root_required if root.nil?
        return :invalid_root unless RecordingStudio.root_recording?(root)
        return :shared_root if RecordingStudio.shared_root?(root)
        return :unauthenticated if actor.nil?

        return if RecordingStudioAccessible.authorized?(actor: actor, recording: root, role: role)

        role.to_s == "admin" ? :not_admin : :forbidden
      end

      def may_manage_root?(actor:, root:)
        root_access_error(actor: actor, root: root, role: :admin).nil?
      end

      def may_use_root?(actor:, root:)
        root_access_error(actor: actor, root: root, role: :view).nil?
      end

      def owned_by_actor?(connection, actor)
        return false if actor.nil? || connection.nil?
        return false if connection.owner_actor_id.blank?

        connection.owner_actor_type == actor.class.name && connection.owner_actor_id.to_s == actor.id.to_s
      end
    end
  end
end
