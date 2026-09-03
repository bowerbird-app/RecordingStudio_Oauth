# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    class OauthClientsController < ApplicationController
      include Concerns::HostAuthentication
      include RecordingStudioAdmin::AdminActionAuditing

      before_action :authenticate_host_user!
      before_action :authorize_admin_actor!
      before_action :authorize_create_resource!, only: %i[new create]

      helper_method :recording_studio_admin_context, :oauth_clients_admin_screen_path

      CREATED_NOTICE = "App created."
      CREATED_SECRET_NOTICE = "App created. Copy the secret now. It will not come back."

      def new
        @oauth_client = OauthClient.new(confidential: false, api_key: Services::CreateOauthClient::DEFAULT_API_KEY)
        @secret_choice = Services::CreateOauthClient::PUBLIC_SECRET_CHOICE
      end

      def create
        return render :new, status: :unprocessable_entity unless oauth_client_persisted?

        redirect_created_oauth_client
      end

      def show
        @oauth_client = OauthClient.find(params[:id])
        @client_secret = flash[:oauth_client_secret]
      end

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

      def authorize_create_resource!
        RecordingStudioAdmin.authorize_resource!(
          key: "oauth_clients",
          action: :create,
          context: recording_studio_admin_context,
          record: OauthClient.new
        )
      rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
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

      def oauth_client_persisted?
        @secret_choice = requested_secret_choice
        perform_recording_studio_admin_action!(
          "oauth_clients",
          :create,
          OauthClient.new,
          audit_action: :create
        ) { create_oauth_client_saved? }
      end

      def create_oauth_client_saved?
        @create_result = Services::CreateOauthClient.call(**create_oauth_client_args)
        return true if @create_result.success?

        @oauth_client = @create_result.errors.first || OauthClient.new
        false
      end

      def create_oauth_client_args
        {
          name: oauth_client_params[:name],
          redirect_uris: Services::CreateOauthClient.redirect_uris_from_lines(oauth_client_params[:redirect_uris]),
          confidential: Services::CreateOauthClient.confidential?(requested_secret_choice)
        }
      end

      def requested_secret_choice
        oauth_client_params[:secret].presence || Services::CreateOauthClient::PUBLIC_SECRET_CHOICE
      end

      def redirect_created_oauth_client
        payload = @create_result.value
        secret = payload[:client_secret]
        flash[:notice] = secret.present? ? CREATED_SECRET_NOTICE : CREATED_NOTICE
        flash[:oauth_client_secret] = secret if secret.present?
        redirect_to admin_oauth_client_path(payload.fetch(:client))
      end

      def oauth_client_params
        params.fetch(:oauth_client, {}).permit(:name, :redirect_uris, :secret)
      end
    end
  end
end
