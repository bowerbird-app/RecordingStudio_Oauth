# frozen_string_literal: true

module RecordingStudioOauth
  module Outbound
    Provider = Data.define(
      :key, :kind, :authorize_url, :token_url, :scopes, :client_id, :client_secret,
      :pkce, :refresh, :revoke_url, :extra_authorize_params, :http
    ) do
      PUBLIC_ATTRIBUTE_KEYS = %i[
        key kind authorize_url token_url scopes client_id
        pkce refresh revoke_url extra_authorize_params
      ].freeze

      def pkce?
        pkce == true
      end

      def refresh?
        refresh == true
      end

      def revoke?
        revoke_url.present?
      end

      def public_attributes
        PUBLIC_ATTRIBUTE_KEYS.index_with { |name| public_send(name) }.freeze
      end

      def inspect
        "#<RecordingStudioOauth::Outbound::Provider key=#{key.inspect} kind=#{kind.inspect} " \
          "authorize_url=#{authorize_url.inspect} token_url=#{token_url.inspect} " \
          "client_id=#{client_id.inspect} client_secret=[FILTERED]>"
      end

      alias_method :to_s, :inspect

      def pretty_print(printer)
        printer.text inspect
      end

      def to_h
        super.merge(client_secret: "[FILTERED]")
      end
    end
  end
end
