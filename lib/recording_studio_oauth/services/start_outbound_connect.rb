# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  module Services
    class StartOutboundConnect < RecordingStudio::Services::BaseService
      RESERVED_AUTHORIZE_KEYS = %w[
        redirect_uri
        state
        client_id
        response_type
        code_challenge
        code_challenge_method
      ].freeze

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

        owner_error = validate_owner
        return owner_error if owner_error

        handshake = OutboundHandshake.issue!(
          provider_key: provider.key,
          owner_kind: owner_kind,
          root_recording_id: root.id,
          actor: actor,
          return_to: return_to,
          pkce: provider.pkce?
        )

        success(location: authorize_location(provider, handshake), handshake: handshake)
      end

      def validate_owner
        if owner_kind == OutboundConnection::OWNER_ROOT
          error = Outbound::Access.root_access_error(actor: actor, root: root, role: :admin)
          return failure(error) if error
        elsif owner_kind == OutboundConnection::OWNER_USER
          error = Outbound::Access.root_access_error(actor: actor, root: root, role: :view)
          return failure(error) if error
        else
          return failure(:invalid_owner)
        end

        nil
      end

      def authorize_location(provider, handshake)
        params = extra_authorize_params(provider).merge(required_authorize_params(provider, handshake))
        uri = URI.parse(provider.authorize_url)
        query = URI.decode_www_form(uri.query.to_s) + params.to_a
        uri.query = URI.encode_www_form(query)
        uri.to_s
      end

      def extra_authorize_params(provider)
        provider.extra_authorize_params.reject { |key, _value| RESERVED_AUTHORIZE_KEYS.include?(key.to_s) }
      end

      def required_authorize_params(provider, handshake)
        params = {
          "response_type" => "code",
          "client_id" => provider.client_id,
          "redirect_uri" => callback_url,
          "state" => handshake.nonce,
          "scope" => provider.scopes.join(" ")
        }
        return params unless provider.pkce?

        params.merge(
          "code_challenge" => Pkce.s256_challenge(handshake.code_verifier),
          "code_challenge_method" => Pkce::S256
        )
      end

      def service_args
        { provider: provider_key, owner_kind: owner_kind }
      end
    end
  end
end
