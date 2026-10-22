# frozen_string_literal: true

module RecordingStudioOauth
  class OutboundConnection < ApplicationRecord
    self.table_name = "recording_studio_oauth_outbound_connections"
    self.filter_attributes += %i[access_token refresh_token]

    STATUSES = %w[active needs_reconnect revoked].freeze
    OWNER_ROOT = "root"
    OWNER_USER = "user"

    belongs_to :root_recording, class_name: "RecordingStudio::Recording", optional: true, inverse_of: false
    belongs_to :owner_actor, polymorphic: true, optional: true
    belongs_to :connected_by, polymorphic: true

    encrypts :access_token, :refresh_token

    validates :provider_key, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :access_token, presence: true
    validate :exactly_one_owner

    scope :live, -> { where(status: %w[active needs_reconnect]) }
    scope :usable, -> { where(status: "active") }
    scope :for_provider, ->(key) { where(provider_key: key.to_s) }

    def root_owned?
      root_recording_id.present?
    end

    def user_owned?
      owner_actor_id.present?
    end

    def owner_kind
      root_owned? ? OWNER_ROOT : OWNER_USER
    end

    def active?
      status == "active"
    end

    def needs_reconnect?
      status == "needs_reconnect"
    end

    def revoked?
      status == "revoked"
    end

    def expired?(at: Time.current)
      expires_at.present? && expires_at <= at
    end

    def usable?
      active? && !expired?
    end

    private

    def exactly_one_owner
      if root_recording_id.present? && owner_actor_id.blank? && owner_actor_type.blank?
        return
      end
      if root_recording_id.blank? && owner_actor_id.present? && owner_actor_type.present?
        return
      end

      errors.add(:base, "Connection must belong to a workspace or a person, not both")
    end
  end
end
