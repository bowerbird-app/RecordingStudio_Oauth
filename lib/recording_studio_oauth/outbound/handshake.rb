# frozen_string_literal: true

require "json"
require "securerandom"

module RecordingStudioOauth
  module Outbound
    class Handshake
      COOKIE_NAME = :outbound_oauth_handshake

      attr_reader :nonce, :provider_key, :owner_kind, :root_recording_id, :actor_type, :actor_id,
                  :code_verifier, :return_to

      def initialize(nonce:, provider_key:, owner_kind:, root_recording_id:, actor_type:, actor_id:,
                     code_verifier:, return_to:)
        @nonce = nonce.to_s
        @provider_key = provider_key.to_s
        @owner_kind = owner_kind.to_s
        @root_recording_id = root_recording_id.to_s.presence
        @actor_type = actor_type.to_s
        @actor_id = actor_id.to_s
        @code_verifier = code_verifier.to_s.presence
        @return_to = return_to.to_s
      end

      def self.build(provider_key:, owner_kind:, root_recording_id:, actor:, return_to:, pkce:)
        verifier = pkce ? generate_verifier : nil
        new(
          nonce: SecureRandom.urlsafe_base64(24),
          provider_key: provider_key,
          owner_kind: owner_kind,
          root_recording_id: root_recording_id,
          actor_type: actor.class.name,
          actor_id: actor.id,
          code_verifier: verifier,
          return_to: return_to
        )
      end

      def self.generate_verifier
        SecureRandom.urlsafe_base64(32).ljust(43, "a")
      end

      def payload
        {
          "nonce" => nonce,
          "provider_key" => provider_key,
          "owner_kind" => owner_kind,
          "root_recording_id" => root_recording_id,
          "actor_type" => actor_type,
          "actor_id" => actor_id,
          "code_verifier" => code_verifier,
          "return_to" => return_to
        }
      end

      def self.from_cookie(raw)
        data = cookie_hash(raw)
        return if data.blank? || data["nonce"].blank? || data["provider_key"].blank?

        new(
          nonce: data["nonce"],
          provider_key: data["provider_key"],
          owner_kind: data["owner_kind"],
          root_recording_id: data["root_recording_id"],
          actor_type: data["actor_type"],
          actor_id: data["actor_id"],
          code_verifier: data["code_verifier"],
          return_to: data["return_to"]
        )
      end

      def matches_state?(state)
        return false if nonce.blank? || state.to_s.blank?
        return false unless nonce.bytesize == state.to_s.bytesize

        ActiveSupport::SecurityUtils.secure_compare(nonce, state.to_s)
      end

      def self.cookie_hash(raw)
        parsed =
          case raw
          when Hash
            raw
          when String
            JSON.parse(raw)
          end
        return {} unless parsed.is_a?(Hash)

        parsed.stringify_keys
      rescue JSON::ParserError
        {}
      end
      private_class_method :cookie_hash
    end
  end
end
