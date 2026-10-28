# frozen_string_literal: true

module RecordingStudioOauth
  class OauthAuthorizationsController < ApplicationController
    include Concerns::HostAuthentication
    include Concerns::ConnectConsent
    include Concerns::ConnectAuthorizeFlow

    layout "recording_studio_oauth/authorization"

    def new
      return unless @oauth_client

      if @selected_access_recording.present?
        render :new
      else
        @errors << reconnect_missing_access_message if requested_access_recording_id.present?
        render :index
      end
    end

    def create
      return unless @oauth_client
      return deny_authorization if deny_requested?
      return render_selection_error unless @selected_access_recording
      return render_role_error unless role_allowed_for?(@selected_access_recording, requested_role)

      result = create_authorization
      return render_create_failure(result) if result.failure?

      redirect_to_client(code: result.value.fetch(:code))
    end

    private

    def deny_authorization
      redirect_to_client(error: "access_denied", error_description: "The resource owner denied the request")
    end

    def render_create_failure(result)
      @errors << result.error.to_s
      template = reconnect_error?(result.error) ? :index : :new
      render template, status: :unprocessable_entity
    end
  end
end
