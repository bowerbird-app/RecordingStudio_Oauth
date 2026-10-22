# frozen_string_literal: true

require "securerandom"

module RecordingStudioOauth
  class OutboundHandshake < ApplicationRecord
    self.table_name = "recording_studio_oauth_outbound_handshakes"
    self.filter_attributes += %i[code_verifier nonce_digest]

    TTL = 10.minutes
    OWNER_KINDS = [OutboundConnection::OWNER_ROOT, OutboundConnection::OWNER_USER].freeze

    encrypts :code_verifier

    attr_accessor :nonce

    belongs_to :root_recording, class_name: "RecordingStudio::Recording", optional: true, inverse_of: false

    validates :nonce_digest, presence: true
    validates :provider_key, presence: true
    validates :owner_kind, presence: true, inclusion: { in: OWNER_KINDS }
    validates :actor_type, :actor_id, :expires_at, presence: true

    scope :stale, lambda {
      where("consumed_at IS NOT NULL OR expires_at <= ?", Time.current)
    }

    def self.issue!(**args)
      nonce = SecureRandom.urlsafe_base64(24)
      record = create!(actor_attrs(args).merge(secret_attrs(nonce, args)))
      record.nonce = nonce
      record
    end

    def self.actor_attrs(args)
      {
        provider_key: args[:provider_key],
        owner_kind: args[:owner_kind],
        root_recording_id: root_id_for(args),
        actor_type: args[:actor].class.name,
        actor_id: args[:actor].id
      }
    end

    def self.secret_attrs(nonce, args)
      {
        nonce_digest: TokenDigest.digest(nonce),
        code_verifier: args[:pkce] ? generate_verifier : nil,
        return_to: ReturnUrlRules.safe_relative_path(args[:return_to]) || "/",
        expires_at: TTL.from_now
      }
    end

    def self.root_id_for(args)
      args[:root_recording_id] if args[:owner_kind] == OutboundConnection::OWNER_ROOT
    end
    private_class_method :actor_attrs, :secret_attrs, :root_id_for

    def self.find_by_state(state)
      raw = state.to_s
      return if raw.blank?

      find_by(nonce_digest: TokenDigest.digest(raw))
    end

    def self.generate_verifier
      SecureRandom.urlsafe_base64(32).ljust(43, "a")
    end

    def consumed?
      consumed_at.present?
    end

    def expired?(at: Time.current)
      expires_at.blank? || expires_at <= at
    end

    def pending?
      !consumed? && !expired?
    end

    def matches_actor?(actor)
      return false if actor.nil? || actor_type.blank? || actor_id.blank?

      actor_type == actor.class.name && actor_id.to_s == actor.id.to_s
    end

    def root_owned?
      owner_kind == OutboundConnection::OWNER_ROOT
    end

    def consume!
      update!(consumed_at: Time.current)
    end

    def self.cleanup_stale
      stale.delete_all
    end
  end
end
