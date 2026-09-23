# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    class OauthClientsController < ApplicationController
      include Concerns::HostAuthentication
      include RecordingStudioAdmin::AdminActionAuditing

      before_action :authenticate_host_user!
      before_action :authorize_admin_actor!
      before_action :authorize_create_resource!, only: %i[new create]
      before_action :authorize_update_resource!, only: %i[edit update]

      helper_method :recording_studio_admin_context, :oauth_clients_admin_screen_path

      CREATED_NOTICE = "App created."
      CREATED_SECRET_NOTICE = "App created. Copy the secret now. It will not come back."
      SAVED_NOTICE = "App saved."

      def new
        @oauth_client = OauthClient.new(
          confidential: false,
          api_key: Services::CreateOauthClient::DEFAULT_API_KEY,
          use_central_relay: false,
          allow_registration: RecordingStudioOauth.configuration.allow_registration?
        )
        @secret_choice = Services::CreateOauthClient::PUBLIC_SECRET_CHOICE
      end

      def create
        @secret_choice = client_form.secret_choice
        return render :new, status: :unprocessable_entity unless oauth_client_persisted?

        redirect_created_oauth_client
      end

      def show
        @oauth_client = OauthClient.find(params[:id])
        @client_secret = flash[:oauth_client_secret]
      end

      def edit
        @oauth_client = OauthClient.find(params[:id])
      end

      def update
        @oauth_client = OauthClient.find(params[:id])
        return render :edit, status: :unprocessable_entity unless oauth_client_updated?

        redirect_to admin_oauth_client_path(@oauth_client), notice: SAVED_NOTICE
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
        authorize_oauth_client_resource!(:create, OauthClient.new)
      end

      def authorize_update_resource!
        authorize_oauth_client_resource!(:update, OauthClient.find(params[:id]))
      end

      def authorize_oauth_client_resource!(action, record)
        RecordingStudioAdmin.authorize_resource!(
          key: "oauth_clients",
          action: action,
          context: recording_studio_admin_context,
          record: record
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

      def client_form
        @client_form ||= OauthClientForm.new(params)
      end

      def oauth_client_persisted?
        perform_recording_studio_admin_action!(
          "oauth_clients",
          :create,
          OauthClient.new,
          audit_action: :create
        ) { create_oauth_client_saved? }
      end

      def create_oauth_client_saved?
        @create_result = Services::CreateOauthClient.call(**client_form.create_args)
        return true if @create_result.success?

        @oauth_client = @create_result.errors.first || OauthClient.new
        false
      end

      def oauth_client_updated?
        perform_recording_studio_admin_action!(
          "oauth_clients",
          :update,
          @oauth_client,
          audit_action: :update
        ) { update_oauth_client_saved? }
      end

      def update_oauth_client_saved?
        result = Services::UpdateOauthClient.call(**client_form.update_args(@oauth_client))
        return true if result.success?

        @oauth_client = result.errors.first || @oauth_client
        false
      end

      def redirect_created_oauth_client
        payload = @create_result.value
        secret = payload[:client_secret]
        flash[:notice] = secret.present? ? CREATED_SECRET_NOTICE : CREATED_NOTICE
        flash[:oauth_client_secret] = secret if secret.present?
        redirect_to admin_oauth_client_path(payload.fetch(:client))
      end
    end
  end
end
