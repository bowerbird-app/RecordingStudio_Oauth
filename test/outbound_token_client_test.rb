# frozen_string_literal: true

require "test_helper"
require "net/http"
require "net/protocol"
require "openssl"

class OutboundTokenClientTest < Minitest::Test
  def test_network_errors_return_status_zero
    client = RecordingStudioOauth::Outbound::TokenClient.new(provider)

    network_errors.each do |error|
      result = client.stub(:post_form, ->(*) { raise error }) { client.refresh(refresh_token: "rt") }

      refute result.ok?, error.class.name
      assert_equal 0, result.status, error.class.name
      assert_equal error.class.name, result.body["error"], error.class.name
    end
  end

  private

  def network_errors
    [
      Timeout::Error.new,
      Errno::ECONNREFUSED.new,
      Errno::EHOSTUNREACH.new,
      Errno::ECONNRESET.new,
      SocketError.new("no host"),
      EOFError.new,
      JSON::ParserError.new("nope"),
      URI::InvalidURIError.new,
      OpenSSL::SSL::SSLError.new,
      Net::ReadTimeout.new,
      Net::OpenTimeout.new,
      Net::HTTPBadResponse.new("bad"),
      Net::ProtocolError.new("proto")
    ]
  end

  def provider
    RecordingStudioOauth::Outbound::Provider.new(
      key: "drive",
      authorize_url: "https://example.test/auth",
      token_url: "https://example.test/token",
      scopes: ["files.read"],
      client_id: "id",
      client_secret: "secret",
      pkce: true,
      refresh: true,
      revoke_url: "https://example.test/revoke",
      extra_authorize_params: {},
      http: nil
    )
  end
end
