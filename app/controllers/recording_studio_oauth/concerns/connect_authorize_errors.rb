# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module ConnectAuthorizeErrors
      extend ActiveSupport::Concern

      private

      def render_selection_error
        @errors << access_selection_error
        render :index, status: :unprocessable_entity
      end

      def render_role_error
        @errors << Services::CreateOauthAuthorization.role_changed_message
        render :index, status: :unprocessable_entity
      end

      def access_selection_error
        return reconnect_missing_access_message if requested_access_recording_id.present?
        return Copy.t("errors.invite_first") if @access_candidates.empty?

        Copy.t("errors.pick_place")
      end

      def reconnect_missing_access_message
        Services::CreateOauthAuthorization.access_gone_message
      end

      def reconnect_error?(error)
        message = error.to_s
        reconnect_messages.include?(message) || message.include?("exceed")
      end

      def reconnect_messages
        [
          Services::CreateOauthAuthorization.access_gone_message,
          Services::CreateOauthAuthorization.role_changed_message,
          Services::CreateOauthAuthorization::ACCESS_GONE_MESSAGE,
          Services::CreateOauthAuthorization::ROLE_CHANGED_MESSAGE
        ]
      end

      def render_oauth_error(code, description)
        @oauth_error = { error: code, error_description: description }
        render :error, status: OauthErrorMapper.status_for(@oauth_error)
      end
    end
  end
end
