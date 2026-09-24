# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class RecordExternalInstall < RecordingStudio::Services::BaseService
      def initialize(client:, external_id:, provider: nil, root_recording: nil, connected_by: nil)
        @client = client
        @external_id = external_id.to_s
        @provider = (provider.presence || client.session_token_provider).to_s
        @root_recording = root_recording
        @connected_by = connected_by
      end

      private

      attr_reader :client, :external_id, :provider, :root_recording, :connected_by

      def perform
        return failure("client is required") if client.blank?

        normalized_provider = ExternalInstall.normalize_provider(provider)
        normalized_external_id = ExternalInstall.normalize_external_id(external_id)
        return failure("channel is required") if normalized_provider.blank?
        return failure("external id is required") if normalized_external_id.blank?

        install = upsert_install(normalized_provider, normalized_external_id)
        success(install)
      rescue ActiveRecord::RecordInvalid => error
        failure(error.record.errors.full_messages.to_sentence, errors: [error.record])
      end

      def upsert_install(normalized_provider, normalized_external_id)
        install = ExternalInstall.find_or_initialize_by(
          oauth_client: client,
          provider: normalized_provider,
          external_id: normalized_external_id
        )
        install.root_recording = root_recording if root_recording
        install.connected_by = connected_by if connected_by
        install.save!
        install
      rescue ActiveRecord::RecordNotUnique
        ExternalInstall.find_by!(
          oauth_client: client,
          provider: normalized_provider,
          external_id: normalized_external_id
        ).tap do |existing|
          existing.root_recording = root_recording if root_recording
          existing.connected_by = connected_by if connected_by
          existing.save! if existing.changed?
        end
      end

      def service_args
        { client_id: client&.client_id, provider: provider, external_id: external_id }
      end
    end
  end
end
