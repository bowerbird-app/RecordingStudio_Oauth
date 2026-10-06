# frozen_string_literal: true

module RecordingStudioOauth
  class OauthClientRegistrationsController < ActionController::API
    def create
      return render_rate_limited unless RegisterRateLimit.allow?(request.remote_ip)

      result = Services::RegisterOauthClient.call(metadata: registration_metadata)
      if result.success?
        render json: result.value, status: :created
      else
        payload = OauthErrorMapper.payload_for(result.error)
        render json: payload, status: OauthErrorMapper.status_for(payload)
      end
    end

    private

    def registration_metadata
      if request.content_mime_type&.json?
        JSON.parse(request.raw_post)
      else
        params.except(:controller, :action, :format)
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
