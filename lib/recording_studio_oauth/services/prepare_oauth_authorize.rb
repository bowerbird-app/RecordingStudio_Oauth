# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class PrepareOauthAuthorize < RecordingStudio::Services::BaseService
      def initialize(params:, actor:, base_url:)
        @params = params
        @actor = actor
        @base_url = base_url
      end

      private

      attr_reader :params, :actor, :base_url

      def perform
        prepared = request_fields
        halt = protocol_halt(prepared)
        return success(prepared.merge(halt: halt, access_candidates: [], selected_access_recording: nil)) if halt

        resolved = Integration.resolve_access_recording_for_actor(
          actor: actor,
          requested_access_recording_id: requested_access_recording_id,
          oauth_client: prepared[:oauth_client]
        )
        candidates = Array(resolved.fetch(:candidates))
        success(
          prepared.merge(
            halt: nil,
            access_candidates: candidates,
            selected_access_recording: selected_access_recording(candidates)
          )
        )
      end

      def request_fields
        {
          errors: [],
          state: params[:state].to_s.presence,
          redirect_uri: params[:redirect_uri].to_s,
          code_challenge: params[:code_challenge].to_s.presence,
          code_challenge_method: code_challenge_method,
          response_type: params[:response_type].to_s,
          resource: params[:resource].to_s.presence,
          api_key: params[:api_key].to_s.presence || "public",
          oauth_client: nil
        }
      end

      def code_challenge_method
        params[:code_challenge_method].to_s.presence || (params[:code_challenge].present? ? Pkce::S256 : nil)
      end

      def requested_access_recording_id
        params[:access_recording_id].to_s.presence
      end

      def selected_access_recording(candidates)
        requested_id = requested_access_recording_id
        return nil if requested_id.blank?

        candidates.find { |recording| recording.id == requested_id }
      end

      def protocol_halt(prepared)
        return error_halt("unsupported_response_type", "response_type must be code") unless prepared[:response_type] == "code"
        return error_halt("invalid_target", "resource is not a registered protected resource") unless resource_allowed?(prepared)

        client_result = ResolveOauthClient.call(client_id: params[:client_id], api: prepared[:api_key])
        return error_halt("invalid_client", "client is invalid") unless client_result.success?

        prepared[:oauth_client] = client_result.value
        return error_halt("invalid_request", "redirect_uri does not match") unless prepared[:oauth_client].redirect_uri_allowed?(prepared[:redirect_uri])

        pkce_halt(prepared)
      end

      def resource_allowed?(prepared)
        RecordingStudioOauth.protected_resources(api_key: prepared[:api_key]).permit?(
          params[:resource],
          base_url: base_url
        )
      end

      def pkce_halt(prepared)
        client = prepared[:oauth_client]
        challenge = prepared[:code_challenge]
        method = prepared[:code_challenge_method]
        return redirect_halt("invalid_request", "PKCE S256 is required for public clients") if client.public? && (challenge.blank? || method != Pkce::S256)

        return unless method.present? && method != Pkce::S256

        redirect_halt("invalid_request", "PKCE method must be S256")
      end

      def error_halt(code, description)
        { kind: :error, error: code, error_description: description }
      end

      def redirect_halt(code, description)
        { kind: :redirect, error: code, error_description: description }
      end

      def service_args
        { actor: actor, base_url: base_url }
      end
    end
  end
end
