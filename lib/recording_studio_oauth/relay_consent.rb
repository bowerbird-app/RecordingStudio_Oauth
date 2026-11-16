# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  class RelayConsent
    def initialize(client:, redirect_uri:, state:, callback_url:)
      @client = client
      @redirect_uri = redirect_uri.to_s
      @state = state.to_s
      @callback_url = callback_url.to_s
    end

    def relay?
      callback_url.present? && redirect_uri == callback_url
    end

    def show_allow?
      !relay? || return_allowed?
    end

    def refused?
      relay? && !return_allowed?
    end

    def host
      return unless relay?

      uri = ReturnUrlRules.http_uri(ticket&.return_to.to_s)
      return if uri.nil? || ReturnUrlRules.unsafe_http?(uri)

      label = uri.host.to_s.downcase
      return label if uri.port == default_port(uri)

      "#{label}:#{uri.port}"
    end

    private

    attr_reader :client, :redirect_uri, :state, :callback_url

    def return_allowed?
      return false if client.nil? || ticket.nil?
      return false unless ticket.client_id == client.client_id.to_s

      client.allows_return_to?(ticket.return_to)
    end

    def ticket
      return @ticket if defined?(@ticket)

      @ticket = CentralRelayState.parse(state)
    end

    def default_port(uri)
      uri.is_a?(URI::HTTPS) ? 443 : 80
    end
  end
end
