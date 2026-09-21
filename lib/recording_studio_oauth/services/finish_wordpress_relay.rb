# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  module Services
    class FinishWordPressRelay < RecordingStudio::Services::BaseService
      INVALID_RETURN = "This Connect return is not valid. Start again from WordPress."

      def initialize(state:, code: nil, error: nil, error_description: nil, find_authorization_code: nil, state_secret: nil)
        @state = state.to_s
        @code = code.to_s.presence
        @error = error.to_s.presence
        @error_description = error_description.to_s.presence
        @find_authorization_code = find_authorization_code
        @state_secret = state_secret
      end

      private

      attr_reader :state, :code, :error, :error_description, :find_authorization_code, :state_secret

      def perform
        ticket = WordPressRelayState.parse(state, secret: state_secret)
        return oauth_failure("invalid_request", INVALID_RETURN) if ticket.nil?

        if code.present?
          return oauth_failure("invalid_request", INVALID_RETURN) unless code_matches_ticket?(ticket)

          return success(location: location_for(ticket, code: code))
        end

        return oauth_failure("invalid_request", "Connect did not finish.") if error.blank?

        success(location: location_for(ticket, error: error, error_description: error_description))
      end

      def code_matches_ticket?(ticket)
        stored = lookup_authorization_code
        return false if stored.nil?
        return false if stored.code_challenge.to_s.blank?

        ActiveSupport::SecurityUtils.secure_compare(stored.code_challenge.to_s, ticket.code_challenge)
      end

      def lookup_authorization_code
        return find_authorization_code.call(code) if find_authorization_code
        return nil unless AuthorizationCode.valid_format?(code)

        AuthorizationCode.find_by_token(OauthAuthorizationCode, code)
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
