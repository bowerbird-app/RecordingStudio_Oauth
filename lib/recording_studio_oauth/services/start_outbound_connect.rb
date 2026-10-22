# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  module Services
    class StartOutboundConnect < RecordingStudio::Services::BaseService
      def initialize(provider:, actor:, owner_kind:, callback_url:, root: nil, return_to: "/")
        @provider_key = provider.to_s
        @actor = actor
        @owner_kind = owner_kind.to_s
        @root = root
        @return_to = return_to
        @callback_url = callback_url.to_s
      end

      private

      attr_reader :provider_key, :actor, :owner_kind, :root, :return_to, :callback_url

      def perform
        provider = Outbound.provider(provider_key)
        return failure(:unknown_provider) if provider.nil?
        return failure(:unauthenticated) if actor.nil?

        if owner_kind == OutboundConnection::OWNER_ROOT
          root_check = validate_root_owner
          return root_check if root_check
        elsif owner_kind != OutboundConnection::OWNER_USER
          return failure(:invalid_owner)
        end

        handshake = Outbound::Handshake.build(
          provider_key: provider.key,
          owner_kind: owner_kind,
          root_recording_id: owner_kind == OutboundConnection::OWNER_ROOT ? root.id : nil,
          actor: actor,
          return_to: return_to,
          pkce: provider.pkce?
        )

        success(
          location: authorize_location(provider, handshake),
          handshake: handshake
        )
      end

      def validate_root_owner
        return failure(:root_required) if root.nil?
        return failure(:shared_root) if Outbound::Access.shared_root?(root)
        return failure(:not_admin) unless Outbound::Access.may_manage_root?(actor: actor, root: root)

        nil
      end

      def authorize_location(provider, handshake)
        params = {
          "response_type" => "code",
          "client_id" => provider.client_id,
          "redirect_uri" => callback_url,
          "state" => handshake.nonce,
          "scope" => provider.scopes.join(" ")
        }
        if provider.pkce?
          params["code_challenge"] = Pkce.s256_challenge(handshake.code_verifier)
          params["code_challenge_method"] = Pkce::S256
        end
        provider.extra_authorize_params.each { |key, value| params[key] = value }

        uri = URI.parse(provider.authorize_url)
        query = URI.decode_www_form(uri.query.to_s) + params.to_a
        uri.query = URI.encode_www_form(query)
        uri.to_s
      end

      def service_args
        { provider: provider_key, owner_kind: owner_kind }
      end
    end
  end
end
