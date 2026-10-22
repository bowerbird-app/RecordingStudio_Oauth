# frozen_string_literal: true

require "test_helper"
require "pp"
require "stringio"

class OutboundRegistryTest < Minitest::Test
  SECRET = "drv-client-secret-fixture"

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
    assert_equal SECRET, provider.client_secret
    assert provider.pkce?
    assert provider.refresh?
    assert_equal "https://example.test/revoke", provider.revoke_url
  end

  def test_unknown_registration_key_raises
    assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(**valid_options, unexpected: true)
    end

    assert_nil RecordingStudioOauth::Outbound.provider("drive")
  end

  def test_missing_key_raises
    options = valid_options
    options.delete(:key)

    assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(**options)
    end

    assert_nil RecordingStudioOauth::Outbound.provider("drive")
  end

  def test_http_authorize_url_raises_without_adapter
    assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(**valid_options, authorize_url: "http://example.test/auth")
    end

    assert_nil RecordingStudioOauth::Outbound.provider("drive")
  end

  def test_http_true_does_not_skip_https
    assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(
        **valid_options,
        authorize_url: "http://example.test/auth",
        http: true
      )
    end

    assert_nil RecordingStudioOauth::Outbound.provider("drive")
  end

  def test_callable_http_does_not_skip_https_on_authorize_url
    assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(
        **valid_options,
        authorize_url: "http://example.test/auth",
        http: ->(_url, _params) { [200, {}] }
      )
    end

    assert_nil RecordingStudioOauth::Outbound.provider("drive")
  end

  def test_relative_urls_allowed_with_http_adapter
    provider = RecordingStudioOauth.register_outbound_provider(
      key: :fake,
      authorize_url: "/fake/authorize",
      token_url: "/fake/token",
      revoke_url: "/fake/revoke",
      client_id: "id",
      client_secret: SECRET,
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
      client_secret: SECRET
    )

    assert provider.pkce?
    assert provider.refresh?
  end

  def test_client_secret_is_redacted_from_inspect
    provider = RecordingStudioOauth.register_outbound_provider(**valid_options)

    refute_includes provider.inspect, SECRET
    assert_includes provider.inspect, "client_secret=[FILTERED]"
  end

  def test_client_secret_is_redacted_from_to_s_pretty_print_and_to_h
    provider = RecordingStudioOauth.register_outbound_provider(**valid_options)

    refute_includes provider.to_s, SECRET
    assert_includes provider.to_s, "[FILTERED]"

    refute_includes provider.pretty_inspect, SECRET
    assert_includes provider.pretty_inspect, "[FILTERED]"

    printed = StringIO.new
    PP.pp(provider, printed)
    refute_includes printed.string, SECRET
    assert_includes printed.string, "[FILTERED]"

    hash = provider.to_h
    assert_equal "[FILTERED]", hash[:client_secret]
    refute_includes hash.inspect, SECRET
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
      client_secret: SECRET,
      pkce: true,
      refresh: true,
      revoke_url: "https://example.test/revoke"
    }
  end
end
