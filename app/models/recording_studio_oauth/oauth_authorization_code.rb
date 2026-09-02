# frozen_string_literal: true

module RecordingStudioOauth
  class OauthAuthorizationCode < ApplicationRecord
    self.table_name = "recording_studio_oauth_authorization_codes"

    belongs_to :oauth_authorization,
               class_name: "RecordingStudioOauth::OauthAuthorization",
               inverse_of: :authorization_codes

    validates :code_digest, presence: true, uniqueness: true
    validates :redirect_uri, presence: true
    validates :expires_at, presence: true
    validates :code_challenge_method, inclusion: { in: %w[S256], allow_blank: true }

    def used?
      used_at.present?
    end

    def expired?
      expires_at.blank? || !expires_at.future?
    end

    def active?
      !used? && !expired?
    end

    def mark_used!(time: Time.current)
      update_columns(used_at: time, updated_at: time)
    end
  end
end
