# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class AuthenticateOauthClient < RecordingStudio::Services::BaseService
      def initialize(client_id:, client_secret: nil, api: :public)
        @client_id = client_id.to_s
        @client_secret = client_secret.to_s.presence
        @api_key = api.to_s
      end

      private

      attr_reader :client_id, :client_secret, :api_key

      def perform
        return failure("client_id is required") if client_id.blank?

        client = OauthClient.find_by(client_id: client_id)
        return failure("unknown client") if client.nil?
        return failure("client is revoked") if client.revoked?
        return failure("client is not registered for this API") unless client.api_key == api_key

        if client.confidential?
          return failure("client authentication failed") unless client.authenticate_secret?(client_secret)
        elsif client_secret.present?
          return failure("public clients must not send a client secret")
        end

        success(client)
      end

      def service_args
        { client_id: client_id, api_key: api_key }
      end
    end
  end
end
