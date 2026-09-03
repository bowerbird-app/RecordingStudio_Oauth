# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class ResolveOauthClient < RecordingStudio::Services::BaseService
      def initialize(client_id:, api: :public)
        @client_id = client_id.to_s
        @api_key = api.to_s
      end

      private

      attr_reader :client_id, :api_key

      def perform
        return failure("client_id is required") if client_id.blank?

        client = OauthClient.find_by(client_id: client_id)
        return failure("unknown client") if client.nil?
        return failure("client is revoked") if client.revoked?
        return failure("client is not registered for this API") unless client.api_key == api_key

        success(client)
      end

      def service_args
        { client_id: client_id, api_key: api_key }
      end
    end
  end
end
