# frozen_string_literal: true

module RecordingStudioOauth
  module Outbound
    class Registry
      ALLOWED_KEYS = %i[
        key
        authorize_url
        token_url
        scopes
        client_id
        client_secret
        pkce
        refresh
        revoke_url
        extra_authorize_params
        http
      ].freeze

      def initialize
        @providers = {}
      end

      def register(**options)
        options.assert_valid_keys(*ALLOWED_KEYS)
        key = normalize_key(options[:key])
        raise ArgumentError, "provider key is required" if key.blank?
        raise ArgumentError, "authorize_url is required" if options[:authorize_url].to_s.strip.blank?
        raise ArgumentError, "token_url is required" if options[:token_url].to_s.strip.blank?

        client_id, client_secret = resolve_credentials(key, options)
        raise ArgumentError, "client_id is required" if client_id.blank?
        raise ArgumentError, "client_secret is required" if client_secret.blank?

        @providers[key] = Provider.new(
          key: key,
          authorize_url: options[:authorize_url].to_s,
          token_url: options[:token_url].to_s,
          scopes: Array(options[:scopes]).map(&:to_s).freeze,
          client_id: client_id,
          client_secret: client_secret,
          pkce: options.key?(:pkce) ? options[:pkce] == true : true,
          refresh: options.key?(:refresh) ? options[:refresh] == true : true,
          revoke_url: options[:revoke_url].to_s.presence,
          extra_authorize_params: stringify_params(options[:extra_authorize_params]),
          http: options[:http]
        )
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

      def normalize_key(key)
        key.to_s.strip.presence
      end

      def stringify_params(params)
        return {}.freeze unless params.respond_to?(:to_h)

        params.to_h.transform_keys(&:to_s).transform_values(&:to_s).freeze
      end

      def resolve_credentials(key, options)
        from_credentials = credentials_for(key)
        client_id = options[:client_id].presence || from_credentials[:client_id]
        client_secret = options[:client_secret].presence || from_credentials[:client_secret]
        [client_id.to_s.presence, client_secret.to_s.presence]
      end

      def credentials_for(key)
        return {} unless defined?(Rails) && Rails.application.respond_to?(:credentials)

        raw = Rails.application.credentials.dig(:recording_studio_oauth, :outbound, key.to_sym)
        raw = Rails.application.credentials.dig(:recording_studio_oauth, :outbound, key.to_s) if raw.blank?
        return {} unless raw.respond_to?(:to_h)

        hash = raw.to_h
        {
          client_id: hash[:client_id] || hash["client_id"],
          client_secret: hash[:client_secret] || hash["client_secret"]
        }
      end
    end
  end
end
