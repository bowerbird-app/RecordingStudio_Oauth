# frozen_string_literal: true

module RecordingStudioOauth
  class OauthDiscoveriesController < ActionController::API
    def authorization_server
      render json: authorization_server_metadata
    end

    def protected_resource
      render json: protected_resource_metadata
    end

    private

    def authorization_server_metadata
      {
        issuer: issuer,
        authorization_endpoint: authorization_endpoint,
        token_endpoint: token_endpoint,
        revocation_endpoint: revocation_endpoint,
        response_types_supported: ["code"],
        grant_types_supported: Services::IssueDelegatedAccessToken::SUPPORTED_GRANT_TYPES,
        code_challenge_methods_supported: [Pkce::S256],
        token_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post none],
        revocation_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post none],
        response_modes_supported: ["query"]
      }
    end

    def protected_resource_metadata
      {
        resource: resource_identifier,
        authorization_servers: [issuer],
        bearer_methods_supported: ["header"]
      }
    end

    def current_api_key
      params[:api_key].to_s.presence || "public"
    end

    def issuer
      "#{request.base_url}#{issuer_path}"
    end

    def issuer_path
      mount = request.script_name.to_s
      mount = "/recording_studio_oauth" if mount.blank? || mount == "/"
      current_api_key == "public" ? mount : "#{mount}/apis/#{current_api_key}"
    end

    def authorization_endpoint
      "#{request.base_url}#{issuer_path}/oauth/authorize"
    end

    def token_endpoint
      api_mount = RecordingStudioOauth.configuration.api_mount_path.presence || "/recording_studio_api"
      if current_api_key == "public"
        "#{request.base_url}#{api_mount}/oauth/token"
      else
        "#{request.base_url}#{api_mount}/apis/#{current_api_key}/oauth/token"
      end
    end

    def revocation_endpoint
      api_mount = RecordingStudioOauth.configuration.api_mount_path.presence || "/recording_studio_api"
      if current_api_key == "public"
        "#{request.base_url}#{api_mount}/oauth/revoke"
      else
        "#{request.base_url}#{api_mount}/apis/#{current_api_key}/oauth/revoke"
      end
    end

    def resource_identifier
      api_mount = RecordingStudioOauth.configuration.api_mount_path.presence || "/recording_studio_api"
      if current_api_key == "public"
        "#{request.base_url}#{api_mount}/api"
      else
        "#{request.base_url}#{api_mount}/apis/#{current_api_key}"
      end
    end
  end
end
