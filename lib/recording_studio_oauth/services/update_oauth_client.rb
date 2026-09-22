# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class UpdateOauthClient < RecordingStudio::Services::BaseService
      def initialize(client:, name:, redirect_uris:, use_central_relay:, allowed_return_patterns:, exact_return_urls:)
        @client = client
        @name = name.to_s
        @redirect_uris = Array(redirect_uris)
        @use_central_relay = ActiveModel::Type::Boolean.new.cast(use_central_relay) == true
        @allowed_return_patterns = Array(allowed_return_patterns)
        @exact_return_urls = Array(exact_return_urls)
      end

      private

      attr_reader :client, :name, :redirect_uris, :use_central_relay, :allowed_return_patterns, :exact_return_urls

      def perform
        client.assign_attributes(
          name: name,
          redirect_uris: redirect_uris,
          use_central_relay: use_central_relay,
          allowed_return_patterns: allowed_return_patterns,
          exact_return_urls: exact_return_urls
        )

        if client.save
          success(client)
        else
          failure(client.errors.full_messages.to_sentence, errors: [client])
        end
      end

      def service_args
        { client_id: client.client_id, use_central_relay: use_central_relay }
      end
    end
  end
end
