# frozen_string_literal: true

require "test_helper"
require "net/http"
require "net/protocol"
require "openssl"
require "socket"
require "timeout"

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

  def test_errno_etimedout_is_a_network_error
    client = RecordingStudioOauth::Outbound::TokenClient.new(provider)
    result = client.stub(:post_form, ->(*) { raise Errno::ETIMEDOUT }) { client.refresh(refresh_token: "rt") }

    refute result.ok?
    assert_equal 0, result.status
    assert_equal "Errno::ETIMEDOUT", result.body["error"]
  end

  private

  def network_errors
    [
      Timeout::Error.new,
      Errno::ECONNREFUSED.new,
      Errno::ETIMEDOUT.new,
      SocketError.new("no host"),
      EOFError.new,
      IOError.new,
      OpenSSL::SSL::SSLError.new,
      Net::ProtocolError.new("proto")
    ]
  end

  def provider
    RecordingStudioOauth::Outbound::Provider.new(
      key: "drive",
      kind: :root,
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
