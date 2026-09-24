# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "active_support/security_utils"

module RecordingStudioOauth
  module Hs256Jwt
    ALGORITHM = "HS256"
    LEEWAY_SECONDS = 10

    module_function

    def encode(payload, secret, header: { "alg" => ALGORITHM, "typ" => "JWT" })
      encoded_header = encode_json(header)
      encoded_payload = encode_json(payload)
      signature = sign("#{encoded_header}.#{encoded_payload}", secret)
      "#{encoded_header}.#{encoded_payload}.#{encode_bytes(signature)}"
    end

    def decode(token, secret, now: Time.now.to_i, audience: nil, leeway: LEEWAY_SECONDS)
      parts = token.to_s.split(".", 3)
      return [:invalid_token, nil] unless parts.length == 3

      encoded_header, encoded_payload, encoded_signature = parts
      header = decode_json(encoded_header)
      payload = decode_json(encoded_payload)
      return [:invalid_token, nil] if header.nil? || payload.nil?

      alg = header["alg"].to_s
      return [:invalid_token, nil] unless alg == ALGORITHM

      expected = sign("#{encoded_header}.#{encoded_payload}", secret)
      actual = decode_bytes(encoded_signature)
      return [:bad_signature, nil] unless actual && secure_bytes?(expected, actual)

      claim_error = claim_error_for(payload, now: now, audience: audience, leeway: leeway)
      return [claim_error, nil] if claim_error

      [:ok, payload]
    end

    def encode_json(value)
      encode_bytes(JSON.generate(value))
    end

    def decode_json(segment)
      JSON.parse(decode_bytes(segment))
    rescue ArgumentError, JSON::ParserError
      nil
    end

    def encode_bytes(bytes)
      Base64.urlsafe_encode64(bytes, padding: false)
    end

    def decode_bytes(segment)
      Base64.urlsafe_decode64(segment.to_s)
    rescue ArgumentError
      nil
    end

    def sign(input, secret)
      OpenSSL::HMAC.digest("SHA256", secret.to_s, input)
    end

    def secure_bytes?(expected, actual)
      return false unless expected.bytesize == actual.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end

    def claim_error_for(payload, now:, audience:, leeway:)
      exp = integer_claim(payload["exp"])
      nbf = integer_claim(payload["nbf"])
      return :invalid_token if exp.nil? || nbf.nil?
      return :expired if now >= (exp + leeway)
      return :not_yet_valid if now < (nbf - leeway)
      return :wrong_audience if audience.present? && !audience_matches?(payload["aud"], audience)

      nil
    end

    def integer_claim(value)
      return value if value.is_a?(Integer)
      return value.to_i if value.is_a?(String) && value.match?(/\A-?\d+\z/)

      nil
    end

    def audience_matches?(actual, expected)
      expected_text = expected.to_s
      case actual
      when Array
        actual.map(&:to_s).include?(expected_text)
      else
        actual.to_s == expected_text
      end
    end
  end
end
