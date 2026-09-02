# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    class OauthClientsController < ApplicationController
      include Concerns::HostAuthentication

      before_action :authenticate_host_user!
      before_action :authorize_admin_actor!

      def revoke
        client = OauthClient.find(params[:id])
        time = Time.current
        OauthClient.transaction do
          client.revoke!(time: time)
          client.authorizations.find_each do |authorization|
            Services::VoidOauthAuthorization.call(authorization: authorization, time: time)
          end
        end

        redirect_back fallback_location: main_app.root_path, notice: "App revoked."
      end

      private

      def authorize_admin_actor!
        actor = current_oauth_actor
        recording = admin_access_recording
        return if recording && RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

        head :forbidden
      end

      def admin_access_recording
        type_names = Array(RecordingStudioOauth.configuration.admin_root_recordable_type_names)
        RecordingStudio::Recording.unscoped.find_by(recordable_type: type_names, parent_recording_id: nil, trashed_at: nil)
      end
    end
  end
end
