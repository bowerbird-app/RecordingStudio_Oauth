# frozen_string_literal: true

require "json"
require "net/http"
require "net/protocol"
require "openssl"
require "uri"

module RecordingStudioOauth
  module Outbound
    class TokenClient
      TIMEOUT = 10
      NETWORK_ERRORS = [
        Timeout::Error,
        Errno::ECONNREFUSED,
        Errno::EHOSTUNREACH,
        Errno::ECONNRESET,
        SocketError,
        EOFError,
        JSON::ParserError,
        URI::InvalidURIError,
        OpenSSL::SSL::SSLError,
        Net::ReadTimeout,
        Net::OpenTimeout,
        Net::HTTPBadResponse,
        Net::ProtocolError
      ].freeze

      Result = Struct.new(:ok, :status, :body, keyword_init: true) do
        def ok?
          ok == true
        end
      end

      def initialize(provider)
        @provider = provider
      end

      def exchange_code(code:, redirect_uri:, code_verifier:)
        params = {
          "grant_type" => "authorization_code",
          "code" => code.to_s,
          "redirect_uri" => redirect_uri.to_s,
          "client_id" => provider.client_id,
          "client_secret" => provider.client_secret
        }
        params["code_verifier"] = code_verifier if code_verifier.present?
        request(provider.token_url, params)
      end

      def refresh(refresh_token:)
        request(
          provider.token_url,
          {
            "grant_type" => "refresh_token",
            "refresh_token" => refresh_token.to_s,
            "client_id" => provider.client_id,
            "client_secret" => provider.client_secret
          }
        )
      end

      def revoke(token:)
        return Result.new(ok: true, status: 200, body: {}) unless provider.revoke?

        request(provider.revoke_url, { "token" => token.to_s })
      end

      private

      attr_reader :provider

      def request(url, params)
        if provider.http.respond_to?(:call)
          status, body = provider.http.call(url, params)
          return Result.new(ok: status.to_i.between?(200, 299), status: status.to_i, body: stringify_body(body))
        end

        post_form(url, params)
      rescue *NETWORK_ERRORS => e
        Result.new(ok: false, status: 0, body: { "error" => e.class.name })
      end

      def post_form(url, params)
        response = http_post(URI.parse(url.to_s), params)
        Result.new(
          ok: response.code.to_i.between?(200, 299),
          status: response.code.to_i,
          body: parse_body(response.body)
        )
      end

      def http_post(uri, params)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = TIMEOUT
        http.read_timeout = TIMEOUT
        request = form_request(uri, params)
        http.request(request)
      end

      def form_request(uri, params)
        request = Net::HTTP::Post.new(uri.request_uri)
        request.set_form_data(params)
        request["Accept"] = "application/json"
        request
      end

      def parse_body(raw)
        return {} if raw.blank?

        parsed = JSON.parse(raw)
        parsed.is_a?(Hash) ? parsed : {}
      end

      def stringify_body(body)
        return {} if body.nil?
        return body if body.is_a?(Hash)

        {}
      end
    end
  end
end
