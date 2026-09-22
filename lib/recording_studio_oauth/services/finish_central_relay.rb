# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  module Services
    class FinishCentralRelay < RecordingStudio::Services::BaseService
      INVALID_RETURN = "This Connect return is not valid. Start again."

      def initialize(state:, code: nil, error: nil, error_description: nil, find_authorization_code: nil, resolve_client: nil, state_secret: nil)
        @state = state.to_s
        @code = code.to_s.presence
        @error = error.to_s.presence
        @error_description = error_description.to_s.presence
        @find_authorization_code = find_authorization_code
        @resolve_client = resolve_client
        @state_secret = state_secret
      end

      private

      attr_reader :state, :code, :error, :error_description, :find_authorization_code, :resolve_client, :state_secret

      def perform
        ticket = CentralRelayState.parse(state, secret: state_secret)
        return oauth_failure("invalid_request", INVALID_RETURN) if ticket.nil?

        client = lookup_client(ticket)
        return oauth_failure("invalid_request", INVALID_RETURN) unless relay_client?(client)
        return oauth_failure("invalid_request", INVALID_RETURN) unless client.allows_return_to?(ticket.return_to)

        if code.present?
          return oauth_failure("invalid_request", INVALID_RETURN) unless code_matches_ticket?(ticket, client)

          return success(location: location_for(ticket, code: code))
        end

        return oauth_failure("invalid_request", "Connect did not finish.") if error.blank?

        success(location: location_for(ticket, error: error, error_description: error_description))
      end

      def lookup_client(ticket)
        return resolve_client.call(ticket.client_id) if resolve_client

        OauthClient.find_by(client_id: ticket.client_id)
      end

      def relay_client?(client)
        client.present? && !client.revoked? && client.use_central_relay?
      end

      def code_matches_ticket?(ticket, client)
        stored = lookup_authorization_code
        return false if stored.nil?
        return false unless same_text?(stored.code_challenge, ticket.code_challenge)

        same_text?(code_owner_id(stored), client.client_id)
      end

      def lookup_authorization_code
        return find_authorization_code.call(code) if find_authorization_code
        return nil unless AuthorizationCode.valid_format?(code)

        AuthorizationCode.find_by_token(OauthAuthorizationCode, code)
      end

      def code_owner_id(stored)
        owner = stored.oauth_authorization.oauth_client&.client_id if stored.respond_to?(:oauth_authorization) && stored.oauth_authorization
        owner || (stored.client_id if stored.respond_to?(:client_id))
      end

      def same_text?(left, right)
        left = left.to_s
        right = right.to_s
        return false if left.blank? || left.bytesize != right.bytesize

        ActiveSupport::SecurityUtils.secure_compare(left, right)
      end

      def location_for(ticket, **query)
        uri = URI.parse(ticket.return_to)
        existing = URI.decode_www_form(uri.query.to_s).to_h
        existing["code"] = query[:code] if query[:code].present?
        existing["error"] = query[:error] if query[:error].present?
        existing["error_description"] = query[:error_description] if query[:error_description].present?
        existing["state"] = ticket.site_state if ticket.site_state.present?
        uri.query = URI.encode_www_form(existing)
        uri.to_s
      end

      def oauth_failure(code, description)
        failure({ error: code, error_description: description })
      end

      def service_args
        { state_present: state.present?, code_present: code.present? }
      end
    end
  end
end
