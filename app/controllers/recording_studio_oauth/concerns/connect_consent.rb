# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module ConnectConsent
      extend ActiveSupport::Concern

      include ConnectUrls
      include ConnectStatus
      include ConnectRoles

      included do
        helper_method :connect_page_title,
                      :connect_permission_title,
                      :connect_row_label,
                      :access_parent_name
      end

      private

      def connect_page_title
        ConnectHandshake.title(
          plugin_name: @oauth_client.name,
          site_names: connect_title_site_names
        )
      end

      def connect_permission_title
        name = access_parent_name(@selected_access_recording)
        return Copy.t("connect.permissions") if name.blank?

        Copy.t("connect.permissions_with_name", name: name)
      end

      def connect_row_label(access_recording)
        ConnectHandshake.row_label(
          parent_name: access_parent_name(access_recording),
          site_name: connect_site_name_for(access_recording),
          shared_site_name: connect_shared_site_name?
        )
      end

      def access_parent_name(access_recording)
        point = access_recording.parent_recording
        return "" if point.nil? || point.recordable_type == "RecordingStudio::Access"

        named_recordable(point.recordable) || point.recordable_type.to_s.demodulize.underscore.humanize
      end

      def named_recordable(recordable)
        return recordable.name.to_s if recordable.respond_to?(:name) && recordable.name.present?
        return recordable.title.to_s if recordable.respond_to?(:title) && recordable.title.present?

        nil
      end

      def connect_title_site_names
        if @selected_access_recording
          [connect_site_name_for(@selected_access_recording)]
        else
          Array(@access_candidates).map { |recording| connect_site_name_for(recording) }
        end
      end

      def connect_shared_site_name?
        ConnectHandshake.shared_site_name?(Array(@access_candidates).map { |recording| connect_site_name_for(recording) })
      end

      def connect_site_name_for(access_recording)
        RecordingStudioSiteSettings.name_for(connect_site_root_for(access_recording))
      end

      def connect_site_root_for(access_recording)
        recording = access_recording&.parent_recording
        while recording
          return recording if RecordingStudioSiteSettings.site_root?(recording)

          recording = recording.parent_recording
        end

        RecordingStudioSiteSettings.site_root_for(self)
      end
    end
  end
end
