# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module ConnectAuthorizeFlow
      extend ActiveSupport::Concern

      include ConnectAuthorizeErrors

      included do
        before_action :load_oauth_request
      end

      private

      def load_oauth_request
        result = Services::PrepareOauthAuthorize.call(
          params: params,
          actor: current_oauth_actor,
          base_url: request.base_url
        )
        apply_prepared_authorize(result.value)
        halt_prepared_authorize(result.value[:halt])
      end

      def apply_prepared_authorize(prepared)
        assign_request_fields(prepared)
        assign_access_fields(prepared)
      end

      def assign_request_fields(prepared)
        @errors = prepared.fetch(:errors)
        @state = prepared[:state]
        @redirect_uri = prepared[:redirect_uri]
        @code_challenge = prepared[:code_challenge]
        @code_challenge_method = prepared[:code_challenge_method]
        @resource = prepared[:resource]
        @api_key = prepared[:api_key]
      end

      def assign_access_fields(prepared)
        @oauth_client = prepared[:oauth_client]
        @access_candidates = prepared.fetch(:access_candidates)
        @selected_access_recording = prepared[:selected_access_recording]
        @role_options = role_options_for(@selected_access_recording)
      end

      def halt_prepared_authorize(halt)
        return if halt.blank?

        if halt[:kind] == :redirect
          redirect_to_client(error: halt[:error], error_description: halt[:error_description])
        else
          render_oauth_error(halt[:error], halt[:error_description])
        end
      end

      def create_authorization
        Services::CreateOauthAuthorization.call(
          oauth_client: @oauth_client,
          manager_actor: current_oauth_actor,
          access_recording: @selected_access_recording,
          role: requested_role,
          redirect_uri: @redirect_uri,
          code_challenge: @code_challenge,
          code_challenge_method: @code_challenge_method
        )
      end

      def requested_access_recording_id
        params[:access_recording_id].to_s.presence
      end

      def deny_requested?
        %w[cancel deny].include?(params[:decision].to_s)
      end

      def requested_role
        params[:role].to_s.presence || default_consent_role
      end

      def redirect_to_client(**query)
        uri = URI.parse(@redirect_uri)
        existing = URI.decode_www_form(uri.query.to_s).to_h
        existing["state"] = @state if @state.present?
        query.each { |key, value| existing[key.to_s] = value if value.present? }
        uri.query = URI.encode_www_form(existing)
        redirect_to uri.to_s, allow_other_host: true
      end
    end
  end
end
