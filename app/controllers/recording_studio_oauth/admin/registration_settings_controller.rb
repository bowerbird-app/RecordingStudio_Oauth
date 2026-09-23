# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    class RegistrationSettingsController < ApplicationController
      include Concerns::HostAuthentication
      include RecordingStudioAdmin::AdminActionAuditing

      before_action :authenticate_host_user!
      before_action :authorize_admin_actor!
      before_action :load_registration_setting

      helper_method :recording_studio_admin_context, :oauth_clients_admin_screen_path

      SAVED_NOTICE = "Registration saved."

      def show
      end

      def update
        return render :show, status: :unprocessable_entity unless registration_setting_saved?

        redirect_to admin_registration_setting_path, notice: SAVED_NOTICE
      end

      private

      def load_registration_setting
        @registration_setting = RegistrationSetting.current
      end

      def authorize_admin_actor!
        actor = current_oauth_actor
        recording = admin_access_recording
        return if recording && RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

        head :forbidden
      end

      def recording_studio_admin_context
        @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
          params: params.to_unsafe_h,
          current_actor: current_oauth_actor,
          controller: self,
          routes: self,
          view_context: view_context
        )
      end

      def oauth_clients_admin_screen_path
        recording_studio_admin_context.admin_screen_path("oauth_clients")
      end

      def admin_access_recording
        type_names = Array(RecordingStudioOauth.configuration.admin_root_recordable_type_names)
        RecordingStudio::Recording.unscoped.find_by(recordable_type: type_names, parent_recording_id: nil, trashed_at: nil)
      end

      def registration_setting_saved?
        perform_recording_studio_admin_action!(
          "oauth_registration",
          :update,
          @registration_setting,
          audit_action: :update
        ) { save_registration_setting }
      end

      def save_registration_setting
        @registration_setting.allow_registration = registration_flag
        return true if @registration_setting.save

        false
      end

      def registration_flag
        raw = params.fetch(:registration_setting, {})[:allow_registration]
        RegistrationPolicy.flag(raw)
      end
    end
  end
end
