# frozen_string_literal: true

module RecordingStudioOauth
  class WordpressRelaysController < ApplicationController
    layout "recording_studio_oauth/authorization"

    def start
      result = Services::StartWordPressRelay.call(**start_args)
      return render_oauth_error(result.error) if result.failure?

      redirect_to authorize_location(result.value)
    end

    def callback
      result = Services::FinishWordPressRelay.call(
        state: params[:state],
        code: params[:code],
        error: params[:error],
        error_description: params[:error_description]
      )
      return render_oauth_error(result.error) if result.failure?

      redirect_to result.value.fetch(:location), allow_other_host: true
    end

    private

    def start_args
      {
        client_id: params[:client_id],
        return_to: params[:return_to],
        relay_callback_url: relay_callback_url,
        code_challenge: params[:code_challenge],
        code_challenge_method: params[:code_challenge_method],
        site_state: params[:state],
        response_type: params[:response_type],
        resource: params[:resource]
      }
    end

    def relay_callback_url
      origin = RecordingStudioOauth.configuration.public_origin
      return RecordingStudioOauth.wordpress_relay_callback_url(base_url: origin) if origin.present?

      wordpress_oauth_callback_url
    end

    def authorize_location(payload)
      extras = authorize_query(payload)
      return oauth_authorize_path(extras) if payload.fetch(:api_key) == "public"

      named_api_oauth_authorize_path(extras.merge(api_key: payload.fetch(:api_key)))
    end

    def authorize_query(payload)
      {
        response_type: "code",
        client_id: payload.fetch(:client_id),
        redirect_uri: payload.fetch(:redirect_uri),
        state: payload.fetch(:state),
        code_challenge: payload.fetch(:code_challenge),
        code_challenge_method: payload.fetch(:code_challenge_method),
        resource: payload[:resource]
      }.compact
    end

    def render_oauth_error(error)
      @oauth_error = error.is_a?(Hash) ? error.symbolize_keys : { error: "invalid_request", error_description: error.to_s }
      render "recording_studio_oauth/oauth_authorizations/error", status: OauthErrorMapper.status_for(@oauth_error)
    end
  end
end
