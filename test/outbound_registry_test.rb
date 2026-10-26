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
    assert_equal :root, provider.kind
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

  def test_missing_kind_raises
    options = valid_options
    options.delete(:kind)

    error = assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(**options)
    end

    assert_match(/kind is required/, error.message)
    assert_nil RecordingStudioOauth::Outbound.provider("drive")
  end

  def test_unknown_kind_raises
    error = assert_raises(ArgumentError) do
      RecordingStudioOauth.register_outbound_provider(**valid_options, kind: :shared)
    end

    assert_match(/kind must be :root or :user/, error.message)
    assert_includes error.message, ":shared"
    assert_nil RecordingStudioOauth::Outbound.provider("drive")
  end

  def test_string_kind_is_accepted
    provider = RecordingStudioOauth.register_outbound_provider(**valid_options, kind: "user")

    assert_equal :user, provider.kind
  end

  def test_outbound_providers_lists_only_key_and_kind
    RecordingStudioOauth.register_outbound_provider(**valid_options)
    RecordingStudioOauth.register_outbound_provider(**valid_options, key: :mail, kind: :user)

    listed = RecordingStudioOauth.outbound_providers
    assert_equal 2, listed.size
    drive = listed.find { |item| item.fetch(:key) == "drive" }
    mail = listed.find { |item| item.fetch(:key) == "mail" }

    assert_equal({ key: "drive", kind: :root }, drive)
    assert_equal({ key: "mail", kind: :user }, mail)
    refute drive.key?(:client_secret)
    refute drive.key?(:client_id)
    refute drive.key?(:authorize_url)
    refute drive.key?(:token_url)
    refute drive.key?(:scopes)
    refute drive.key?(:http)
    refute_includes listed.inspect, SECRET
    assert listed.frozen?
    assert drive.frozen?
  end

  def test_public_attributes_does_not_expose_fields_outside_the_allowlist
    provider = RecordingStudioOauth.register_outbound_provider(**valid_options)
    listed = provider.public_attributes

    assert_equal(%i[key kind], listed.keys)
    refute listed.key?(:extra_authorize_params)
    refute listed.key?(:pkce)
    refute listed.key?(:refresh)
    refute listed.key?(:revoke_url)
    refute listed.key?(:client_id)
    refute listed.key?(:client_secret)
    refute listed.key?(:http)
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
      kind: :root,
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
      kind: :user,
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
    assert_includes provider.inspect, "kind=:root"
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
    assert_respond_to RecordingStudioOauth, :connection_status
    assert_respond_to RecordingStudioOauth, :connection_id_for
    assert_respond_to RecordingStudioOauth, :connected_user_count
    assert_respond_to RecordingStudioOauth, :register_outbound_provider
    assert_respond_to RecordingStudioOauth, :outbound_providers
    assert_respond_to RecordingStudioOauth, :combined_connection_status
  end

  private

  def valid_options
    {
      key: :drive,
      kind: :root,
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
