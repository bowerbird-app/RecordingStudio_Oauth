# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module ConnectRoles
      extend ActiveSupport::Concern

      included do
        helper_method :show_permission_choice?, :default_consent_role
      end

      private

      def show_permission_choice?
        Array(@role_options).many?
      end

      def default_consent_role
        view_option = Array(@role_options).find { |(_label, value)| value.to_s == "view" }
        view_option&.last || @role_options.first&.last || "view"
      end

      def role_options_for(access_recording)
        current_role = manager_access_role(access_recording)
        return [] if current_role.blank?

        OauthAuthorization.role_names.filter_map do |role|
          next unless OauthAuthorization.role_at_or_below?(role, current_role)

          [Copy.role_name(role), role]
        end
      end

      def role_allowed_for?(access_recording, role)
        OauthAuthorization.role_at_or_below?(role, manager_access_role(access_recording))
      end

      def manager_access_role(access_recording)
        recordable = access_recording&.recordable
        return unless recordable.is_a?(RecordingStudio::Access)

        recordable.role
      end
    end
  end
end
