# frozen_string_literal: true

module RecordingStudioOauth
  class ConnectedAppsController < ApplicationController
    include Concerns::HostAuthentication

    before_action :authenticate_host_user!
    before_action :set_current_actor

    helper_method :connected_app_status

    def index
      @authorizations = OauthAuthorization
                        .includes(:oauth_client, :access_recording)
                        .where(manager_actor: current_oauth_actor)
                        .order(created_at: :desc)
    end

    def destroy
      authorization = OauthAuthorization.find_by!(id: params[:id], manager_actor: current_oauth_actor)
      Services::VoidOauthAuthorization.call(authorization: authorization)

      redirect_to connected_apps_path, notice: Copy.t("flashes.access_removed")
    end

    private

    def connected_app_status(authorization)
      key = authorization.revoked_at.present? ? "connected_apps.status_removed" : "connected_apps.status"
      Copy.t(key, permission: Copy.role_name(authorization.role), workspace: connected_app_workspace_name(authorization))
    end

    def connected_app_workspace_name(authorization)
      workspace = authorization.workspace_recording&.recordable
      return workspace.name if workspace.respond_to?(:name) && workspace.name.present?
      return workspace.title if workspace.respond_to?(:title) && workspace.title.present?

      Copy.t("connected_apps.this_place")
    end
  end
end
