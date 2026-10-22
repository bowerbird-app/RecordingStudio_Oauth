# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class FinishOutboundConnect < RecordingStudio::Services::BaseService
      def initialize(handshake:, state:, code:, actor:, callback_url:)
        @handshake = handshake
        @state = state.to_s
        @code = code.to_s
        @actor = actor
        @callback_url = callback_url.to_s
      end

      private

      attr_reader :handshake, :state, :code, :actor, :callback_url

      def perform
        return failure(:invalid_state) if handshake.nil?
        return failure(:invalid_state) unless handshake.matches_state?(state)
        return failure(:unauthenticated) if actor.nil?
        return failure(:invalid_state) unless actor_matches_handshake?
        return failure(:missing_code) if code.blank?

        provider = Outbound.provider(handshake.provider_key)
        return failure(:unknown_provider) if provider.nil?

        token = Outbound::TokenClient.new(provider).exchange_code(
          code: code,
          redirect_uri: callback_url,
          code_verifier: handshake.code_verifier
        )
        return failure(:token_exchange_failed) unless token.ok?
        return failure(:token_exchange_failed) if token.body["access_token"].to_s.blank?

        connection = upsert_connection!(provider, token.body)
        success(connection: connection, return_to: handshake.return_to)
      rescue ActiveRecord::ActiveRecordError
        failure(:save_failed)
      end

      def actor_matches_handshake?
        handshake.actor_type == actor.class.name && handshake.actor_id.to_s == actor.id.to_s
      end

      def upsert_connection!(provider, body)
        attributes = connection_attributes(provider, body)
        existing = live_connection
        if existing
          existing.update!(attributes.merge(status: "active"))
          existing
        else
          OutboundConnection.create!(attributes.merge(status: "active", provider_key: provider.key))
        end
      end

      def live_connection
        scope = OutboundConnection.live.for_provider(handshake.provider_key)
        if handshake.owner_kind == OutboundConnection::OWNER_ROOT
          scope.find_by(root_recording_id: handshake.root_recording_id)
        else
          scope.find_by(owner_actor_type: handshake.actor_type, owner_actor_id: handshake.actor_id)
        end
      end

      def connection_attributes(provider, body)
        attrs = {
          connected_by_type: actor.class.name,
          connected_by_id: actor.id,
          access_token: body["access_token"].to_s,
          refresh_token: body["refresh_token"].to_s.presence,
          granted_scopes: scopes_from(body, provider),
          expires_at: expires_at_from(body),
          external_account_id: account_id_from(body),
          external_account_label: account_label_from(body)
        }
        if handshake.owner_kind == OutboundConnection::OWNER_ROOT
          attrs[:root_recording_id] = handshake.root_recording_id
          attrs[:owner_actor_type] = nil
          attrs[:owner_actor_id] = nil
        else
          attrs[:root_recording_id] = nil
          attrs[:owner_actor_type] = handshake.actor_type
          attrs[:owner_actor_id] = handshake.actor_id
        end
        attrs
      end

      def scopes_from(body, provider)
        raw = body["scope"].presence || provider.scopes.join(" ")
        raw.to_s.split(/\s+/).reject(&:blank?)
      end

      def expires_at_from(body)
        seconds = body["expires_in"]
        return if seconds.blank?

        Time.current + seconds.to_i.seconds
      end

      def account_id_from(body)
        %w[user_id account_id id sub].each do |key|
          value = body[key].to_s.presence
          return value if value
        end
        nil
      end

      def account_label_from(body)
        %w[email name account_label].each do |key|
          value = body[key].to_s.presence
          return value if value
        end
        nil
      end

      def service_args
        { provider: handshake&.provider_key }
      end
    end
  end
end
