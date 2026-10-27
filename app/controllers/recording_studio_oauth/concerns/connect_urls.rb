# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module ConnectUrls
      extend ActiveSupport::Concern

      included do
        helper_method :authorize_form_url, :connect_choice_url
      end

      private

      def authorize_form_url
        if @api_key == "public"
          oauth_authorize_path
        else
          named_api_oauth_authorize_path(api_key: @api_key)
        end
      end

      def connect_choice_url(access_recording = nil)
        extras = oauth_query_params
        extras[:access_recording_id] = access_recording.id if access_recording
        if @api_key == "public"
          oauth_authorize_path(extras)
        else
          named_api_oauth_authorize_path(extras.merge(api_key: @api_key))
        end
      end

      def oauth_query_params
        {
          response_type: "code",
          client_id: @oauth_client.client_id,
          redirect_uri: @redirect_uri,
          state: @state,
          code_challenge: @code_challenge,
          code_challenge_method: @code_challenge_method,
          resource: @resource
        }.compact
      end
    end
  end
end
