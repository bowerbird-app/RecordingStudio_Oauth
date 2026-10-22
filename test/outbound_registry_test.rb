# frozen_string_literal: true

require "test_helper"

class OutboundRegistryTest < Minitest::Test
  def setup
    RecordingStudioOauth::Outbound.reset_providers!
  end

  def teardown
    RecordingStudioOauth::Outbound.reset_providers!
  end

  def test_register_stores_a_provider
    provider = RecordingStudioOauth.register_outbound_provider(**valid_options)

    assert_equal "drive", provider.key
    assert_equal "https://example.test/auth", provider.authorize_url
    assert_equal "https://example.test/token", provider.token_url
    assert_equal ["files.read"], provider.scopes
    assert_equal "id", provider.client_id
    assert_equal "secret", provider.client_secret
    assert provider.pkce?
    assert provider.refresh?
    assert_equal "https://example.test/revoke", provider.revoke_url
  end

  def test_unknown_registration_key_raises
    error = assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(**valid_options, unexpected: true)
    end

    assert_includes error.message.downcase, "unknown key"
  end

  def test_missing_key_raises
    options = valid_options
    options.delete(:key)

    error = assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(**options)
    end

    assert_equal "provider key is required", error.message
  end

  def test_http_authorize_url_raises_without_adapter
    error = assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(**valid_options, authorize_url: "http://example.test/auth")
    end

    assert_equal "authorize_url must be https", error.message
  end

  def test_relative_urls_allowed_with_http_adapter
    provider = RecordingStudioOauth.register_outbound_provider(
      key: :fake,
      authorize_url: "/fake/authorize",
      token_url: "/fake/token",
      revoke_url: "/fake/revoke",
      client_id: "id",
      client_secret: "secret",
      http: ->(_url, _params) { [200, {}] }
    )

    assert_equal "/fake/authorize", provider.authorize_url
  end

  def test_pkce_and_refresh_default_on
    provider = RecordingStudioOauth.register_outbound_provider(
      key: :plain,
      authorize_url: "https://example.test/auth",
      token_url: "https://example.test/token",
      client_id: "id",
      client_secret: "secret"
    )

    assert provider.pkce?
    assert provider.refresh?
  end

  def test_client_secret_is_redacted_from_inspect
    provider = RecordingStudioOauth.register_outbound_provider(**valid_options)

    refute_includes provider.inspect, "\"secret\""
    assert_includes provider.inspect, "client_secret=[FILTERED]"
  end

  def test_connection_for_is_on_the_public_module
    assert_respond_to RecordingStudioOauth, :connection_for
    assert_respond_to RecordingStudioOauth, :register_outbound_provider
  end

  private

  def valid_options
    {
      key: :drive,
      authorize_url: "https://example.test/auth",
      token_url: "https://example.test/token",
      scopes: ["files.read"],
      client_id: "id",
      client_secret: "secret",
      pkce: true,
      refresh: true,
      revoke_url: "https://example.test/revoke"
    }
  end
end
