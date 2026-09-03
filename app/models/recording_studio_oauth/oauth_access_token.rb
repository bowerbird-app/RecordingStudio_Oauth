# frozen_string_literal: true

module RecordingStudioOauth
  class OauthAccessToken < ApplicationRecord
    self.table_name = "recording_studio_oauth_access_tokens"

    belongs_to :oauth_authorization,
               class_name: "RecordingStudioOauth::OauthAuthorization",
               inverse_of: :access_tokens

    validates :token_digest, presence: true, uniqueness: true
    validates :token_prefix, presence: true
    validates :expires_at, presence: true

    scope :active, lambda {
      where(revoked_at: nil).where(arel_table[:expires_at].gt(Time.current))
    }

    def revoked?
      revoked_at.present?
    end

    def expired?
      expires_at.blank? || !expires_at.future?
    end

    def active?
      !revoked? && !expired? && oauth_authorization&.active?
    end

    def active_for_authentication?
      active?
    end

    def api_client
      oauth_authorization&.oauth_client
    end

    def effective_access_recording
      oauth_authorization&.access_recording
    end

    def effective_access_recording_id
      oauth_authorization&.access_recording_id
    end

    def revoke_tokens_on_expiry!
      return if oauth_authorization.nil?

      Services::VoidOauthAuthorization.call(authorization: oauth_authorization)
    end

    def revoke!(time: Time.current)
      update_columns(revoked_at: time, updated_at: time) if revoked_at.nil?
    end
  end
end
