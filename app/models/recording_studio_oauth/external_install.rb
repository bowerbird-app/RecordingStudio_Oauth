# frozen_string_literal: true

module RecordingStudioOauth
  class ExternalInstall < ApplicationRecord
    self.table_name = "recording_studio_oauth_external_installs"

    belongs_to :oauth_client, class_name: "RecordingStudioOauth::OauthClient", inverse_of: :external_installs
    belongs_to :root_recording, class_name: "RecordingStudio::Recording", optional: true, inverse_of: false
    belongs_to :connected_by, polymorphic: true, optional: true

    before_validation :normalize_keys

    validates :provider, presence: true
    validates :external_id, presence: true
    validates :oauth_client, presence: true
    validates :external_id, uniqueness: { scope: %i[oauth_client_id provider] }

    def connected?
      root_recording_id.present?
    end

    def workspace
      root_recording&.recordable
    end

    def self.normalize_provider(value)
      value.to_s.strip.downcase.presence
    end

    def self.normalize_external_id(value)
      value.to_s.strip.downcase.presence
    end

    private

    def normalize_keys
      self.provider = self.class.normalize_provider(provider)
      self.external_id = self.class.normalize_external_id(external_id)
    end
  end
end
