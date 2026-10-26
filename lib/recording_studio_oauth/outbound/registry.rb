# frozen_string_literal: true

require "recording_studio_oauth/outbound/https_url"

module RecordingStudioOauth
  module Outbound
    class Registry
      ALLOWED_KEYS = %i[
        key kind authorize_url token_url scopes client_id client_secret
        pkce refresh revoke_url extra_authorize_params http
      ].freeze

      KINDS = %i[root user].freeze

      def initialize
        @providers = {}
      end

      def register(**options)
        options.assert_valid_keys(*ALLOWED_KEYS)
        key = require_present(options[:key], "provider key is required")
        kind = require_kind(options[:kind])
        require_present(options[:authorize_url], "authorize_url is required")
        require_present(options[:token_url], "token_url is required")
        HttpsUrl.assert_endpoints!(options)
        client_id, client_secret = require_credentials(key, options)
        @providers[key] = Provider.new(**provider_attrs(key, kind, options, client_id, client_secret))
      end

      def fetch(key)
        @providers[normalize_key(key)]
      end

      def all
        @providers.dup
      end

      def reset!
        @providers = {}
      end

      private

      def require_present(value, message)
        normalized = value.to_s.strip.presence
        raise ArgumentError, message if normalized.blank?

        normalized
      end

      def require_credentials(key, options)
        client_id, client_secret = resolve_credentials(key, options)
        raise ArgumentError, "client_id is required" if client_id.blank?
        raise ArgumentError, "client_secret is required" if client_secret.blank?

        [client_id, client_secret]
      end

      def require_kind(value)
        raise ArgumentError, "kind is required (must be :root or :user)" if value.nil?

        kind = value.to_s.strip.downcase
        raise ArgumentError, "kind is required (must be :root or :user)" if kind.blank?

        kind = kind.to_sym
        return kind if KINDS.include?(kind)

        raise ArgumentError, "kind must be :root or :user, got #{value.inspect}"
      end

      def provider_attrs(key, kind, options, client_id, client_secret)
        {
          key: key,
          kind: kind,
          authorize_url: options[:authorize_url].to_s,
          token_url: options[:token_url].to_s,
          scopes: Array(options[:scopes]).map(&:to_s).freeze,
          client_id: client_id,
          client_secret: client_secret
        }.merge(provider_flags(options))
      end

      def provider_flags(options)
        {
          pkce: options.fetch(:pkce, true) == true,
          refresh: options.fetch(:refresh, true) == true,
          revoke_url: options[:revoke_url].to_s.presence,
          extra_authorize_params: stringify_params(options[:extra_authorize_params]),
          http: options[:http]
        }
      end

      def normalize_key(key)
        key.to_s.strip.presence
      end

      def stringify_params(params)
        return {}.freeze unless params.respond_to?(:to_h)

        params.to_h.transform_keys(&:to_s).transform_values(&:to_s).freeze
      end

      def resolve_credentials(key, options)
        stored = credentials_for(key)
        client_id = options[:client_id].presence || stored[:client_id]
        client_secret = options[:client_secret].presence || stored[:client_secret]
        [client_id.to_s.presence, client_secret.to_s.presence]
      end

      def credentials_for(key)
        raw = credential_hash(key)
        return {} if raw.nil?

        {
          client_id: raw[:client_id] || raw["client_id"],
          client_secret: raw[:client_secret] || raw["client_secret"]
        }
      end

      def credential_hash(key)
        return unless defined?(Rails) && Rails.application.respond_to?(:credentials)

        creds = Rails.application.credentials
        raw = creds.dig(:recording_studio_oauth, :outbound, key.to_sym)
        raw = creds.dig(:recording_studio_oauth, :outbound, key.to_s) if raw.blank?
        raw.respond_to?(:to_h) ? raw.to_h : nil
      end
    end
  end
end
