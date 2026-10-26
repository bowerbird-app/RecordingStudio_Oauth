# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class FinishOutboundConnect < RecordingStudio::Services::BaseService
      HandshakeGone = Class.new(StandardError)

      def initialize(state:, code:, actor:, callback_url:)
        @state = state.to_s
        @code = code.to_s
        @actor = actor
        @callback_url = callback_url.to_s
      end

      private

      attr_reader :state, :code, :actor, :callback_url

      def perform
        return failure(:unauthenticated) if actor.nil?
        return failure(:invalid_state) if state.blank?
        return failure(:missing_code) if code.blank?

        pending = pending_handshake
        return failure(:invalid_state) if pending.nil?
        return failure(:invalid_state) unless pending.matches_actor?(actor)

        root_error = recheck_root(pending)
        return failure(root_error) if root_error

        provider = Outbound.provider(pending.provider_key)
        return failure(:unknown_provider) if provider.nil?

        consume_handshake!(pending)

        token = Outbound::TokenClient.new(provider).exchange_code(
          code: code,
          redirect_uri: callback_url,
          code_verifier: pending.code_verifier
        )
        return failure(:token_exchange_failed) unless token.ok?
        return failure(:token_exchange_failed) if token.body["access_token"].to_s.blank?

        connection = upsert_connection!(pending, provider, token.body)
        success(connection: connection, return_to: pending.return_to)
      rescue HandshakeGone
        failure(:invalid_state)
      rescue ActiveRecord::ActiveRecordError
        failure(:save_failed)
      end

      def pending_handshake
        return @pending_handshake if defined?(@pending_handshake)

        @pending_handshake = load_pending_handshake
      end

      def load_pending_handshake
        pending = OutboundHandshake.find_by_state(state)
        return if pending.nil? || pending.consumed? || pending.expired?

        pending
      end

      def recheck_root(pending)
        root = RecordingStudio::Recording.find_by(id: pending.root_recording_id)
        role = pending.root_owned? ? :admin : :view
        Outbound::Access.root_access_error(actor: actor, root: root, role: role)
      end

      def consume_handshake!(pending)
        OutboundHandshake.transaction do
          locked = OutboundHandshake.lock.find_by(id: pending.id)
          raise HandshakeGone if locked.nil? || locked.consumed? || locked.expired?

          live = live_connection(locked)
          live&.lock!
          locked.consume!
          @pending_handshake = locked
        end
      end

      def upsert_connection!(handshake, provider, body)
        attributes = connection_attributes(handshake, provider, body)
        existing = live_connection(handshake)
        if existing
          existing.update!(attributes.merge(status: "active"))
          existing
        else
          create_live_connection!(handshake, provider, attributes)
        end
      end

      def create_live_connection!(handshake, provider, attributes)
        OutboundConnection.create!(attributes.merge(status: "active", provider_key: provider.key))
      rescue ActiveRecord::RecordNotUnique
        live = live_connection_scope(handshake).first
        raise unless live

        live.update!(attributes.merge(status: "active"))
        live
      end

      def live_connection(handshake)
        live_connection_scope(handshake).first
      end

      def live_connection_scope(handshake)
        scope = OutboundConnection.live.for_provider(handshake.provider_key)
        if handshake.root_owned?
          scope.where(root_recording_id: handshake.root_recording_id, owner_actor_id: nil)
        else
          scope.where(
            owner_actor_type: handshake.actor_type,
            owner_actor_id: handshake.actor_id,
            root_recording_id: handshake.root_recording_id
          )
        end
      end

      def connection_attributes(handshake, provider, body)
        attrs = token_attributes(provider, body)
        if handshake.root_owned?
          attrs.merge(
            root_recording_id: handshake.root_recording_id,
            owner_actor_type: nil,
            owner_actor_id: nil
          )
        else
          attrs.merge(
            root_recording_id: handshake.root_recording_id,
            owner_actor_type: handshake.actor_type,
            owner_actor_id: handshake.actor_id
          )
        end
      end

      def token_attributes(provider, body)
        {
          connected_by_type: actor.class.name,
          connected_by_id: actor.id,
          access_token: body["access_token"].to_s,
          refresh_token: body["refresh_token"].to_s.presence,
          granted_scopes: scopes_from(body, provider),
          expires_at: expires_at_from(body),
          external_account_id: account_id_from(body),
          external_account_label: account_label_from(body)
        }
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
        { provider: pending_handshake&.provider_key }
      end
    end
  end
end
