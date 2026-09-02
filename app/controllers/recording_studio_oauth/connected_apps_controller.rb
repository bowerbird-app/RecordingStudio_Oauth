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

      redirect_to connected_apps_path, notice: "App access removed."
    end

    private

    def connected_app_status(authorization)
      workspace = authorization.workspace_recording&.recordable
      workspace_name = if workspace.respond_to?(:name) && workspace.name.present?
                         workspace.name
                       elsif workspace.respond_to?(:title) && workspace.title.present?
                         workspace.title
                       else
                         "this place"
                       end
      permission = authorization.role.to_s.humanize
      return "#{permission} on #{workspace_name} · removed" if authorization.revoked_at.present?

      "#{permission} on #{workspace_name}"
    end
  end
end
