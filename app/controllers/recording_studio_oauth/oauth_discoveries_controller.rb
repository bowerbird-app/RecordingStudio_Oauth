# frozen_string_literal: true

module RecordingStudioOauth
  class OauthDiscoveriesController < ActionController::API
    include Concerns::OauthDiscoveryApiKey

    def authorization_server
      return head :not_found unless known_issuer_path?

      render json: authorization_server_metadata
    end

    def protected_resource
      registry = RecordingStudioOauth.protected_resources(api_key: current_api_key)
      entry = protected_resource_entry(registry)
      return head :not_found unless entry

      render json: entry.metadata(base_url: request.base_url, issuer: issuer)
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
      }.merge(registration_metadata)
    end

    def registration_metadata
      return {} unless RecordingStudioOauth.configuration.allow_self_registered_apps?

      { registration_endpoint: "#{issuer}/register" }
    end

    def issuer
      "#{request.base_url}#{issuer_path}"
    end

    def issuer_path
      inserted = inserted_issuer_path
      return inserted if inserted.present?

      mount = request.script_name.to_s
      mount = configured_mount_path if mount.blank? || mount == "/"
      current_api_key == "public" ? mount : "#{mount}/apis/#{current_api_key}"
    end

    def protected_resource_entry(registry)
      suffix = params[:resource_path]
      if suffix.present?
        registry.resolve(path_suffix: suffix.to_s)
      elsif origin_protected_resource_request?
        registry.resolve(path_suffix: "")
      else
        registry.find(kind: :api)
      end
    end

    def origin_protected_resource_request?
      mount = request.script_name.to_s
      mount.blank? || mount == "/"
    end

    def authorization_endpoint
      "#{request.base_url}#{issuer_path}/oauth/authorize"
    end

    def token_endpoint
      api_mount = configured_api_mount_path
      if current_api_key == "public"
        "#{request.base_url}#{api_mount}/oauth/token"
      else
        "#{request.base_url}#{api_mount}/apis/#{current_api_key}/oauth/token"
      end
    end

    def revocation_endpoint
      api_mount = configured_api_mount_path
      if current_api_key == "public"
        "#{request.base_url}#{api_mount}/oauth/revoke"
      else
        "#{request.base_url}#{api_mount}/apis/#{current_api_key}/oauth/revoke"
      end
    end
  end
end
