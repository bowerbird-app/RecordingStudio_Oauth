# frozen_string_literal: true

module RecordingStudioOauth
  class OauthClientRegistrationsController < ActionController::API
    def create
      return render_rate_limited unless RegisterRateLimit.allow?(request.remote_ip)

      return render_unknown_api unless known_api_key?

      result = Services::RegisterOauthClient.call(metadata: registration_metadata, api_key: api_key)
      if result.success?
        render json: result.value, status: :created
      else
        payload = OauthErrorMapper.payload_for(result.error)
        render json: payload, status: OauthErrorMapper.status_for(payload)
      end
    end

    private

    def api_key
      params[:api_key].to_s.presence || Integration::DEFAULT_API_NAME
    end

    def known_api_key?
      Integration.api_names.map(&:to_s).include?(api_key)
    end

    def render_unknown_api
      payload = {
        error: "invalid_request",
        error_description: "Unknown API."
      }
      render json: payload, status: :not_found
    end

    def registration_metadata
      if request.content_mime_type&.json?
        JSON.parse(request.raw_post)
      else
        params.except(:controller, :action, :format, :api_key)
      end
    rescue JSON::ParserError
      {}
    end

    def render_rate_limited
      payload = {
        error: "temporarily_unavailable",
        error_description: "Too many registration requests. Try again in a minute."
      }
      render json: payload, status: :too_many_requests
    end
  end
end
