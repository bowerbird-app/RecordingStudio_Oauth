# frozen_string_literal: true

require "test_helper"

class StartWordPressRelayTest < Minitest::Test
  SECRET = "wordpress-relay-test-secret"
  RELAY = "https://app.example.com/recording_studio_oauth/wordpress/callback"
  RETURN_TO = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  CHALLENGE = "pkce-challenge-value"

  FakeClient = Struct.new(:client_id, :api_key, :redirect_uris, :public_client, :revoked, keyword_init: true) do
    def public?
      public_client
    end

    def revoked?
      revoked
    end

    def redirect_uri_allowed?(uri)
      Array(redirect_uris).include?(uri)
    end
  end

  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
    @client = FakeClient.new(
      client_id: "wp_public",
      api_key: "public",
      redirect_uris: [RELAY],
      public_client: true,
      revoked: false
    )
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_happy_path_binds_return_and_uses_relay_redirect
    result = start_relay

    assert result.success?, result.error.inspect
    assert_equal RELAY, result.value.fetch(:redirect_uri)
    assert_equal "wp_public", result.value.fetch(:client_id)
    assert_equal "public", result.value.fetch(:api_key)
    assert_equal CHALLENGE, result.value.fetch(:code_challenge)
    assert_equal "S256", result.value.fetch(:code_challenge_method)

    ticket = RecordingStudioOauth::WordPressRelayState.parse(result.value.fetch(:state), secret: SECRET)
    assert_equal RETURN_TO, ticket.return_to
    assert_equal "wp-csrf", ticket.site_state
    assert_equal CHALLENGE, ticket.code_challenge
  end

  def test_rejects_unknown_client_id
    result = start_relay(resolve_client: ->(_id) {})

    assert result.failure?
    assert_equal "invalid_client", result.error.fetch(:error)
    assert_equal "This app is not registered.", result.error.fetch(:error_description)
  end

  def test_rejects_open_redirect_return
    result = start_relay(return_to: "https://evil.example/steal")

    assert result.failure?
    assert_equal "invalid_request", result.error.fetch(:error)
    assert_equal "That WordPress return address is not allowed.", result.error.fetch(:error_description)
  end

  def test_rejects_return_with_extra_query
    result = start_relay(
      return_to: "#{RETURN_TO}&redirect=https://evil.example"
    )

    assert result.failure?
    assert_equal "That WordPress return address is not allowed.", result.error.fetch(:error_description)
  end

  def test_rejects_when_relay_is_not_registered_on_client
    @client.redirect_uris = ["https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"]

    result = start_relay

    assert result.failure?
    assert_equal "This app is not set up for WordPress Connect.", result.error.fetch(:error_description)
  end

  def test_requires_pkce_s256_for_public_clients
    result = start_relay(code_challenge: nil)

    assert result.failure?
    assert_equal "Connect needs a proof key.", result.error.fetch(:error_description)
  end

  def test_ignores_client_supplied_redirect_by_using_only_relay_callback_url
    result = start_relay

    assert result.success?
    refute_equal RETURN_TO, result.value.fetch(:redirect_uri)
  end

  private

  def start_relay(**overrides)
    RecordingStudioOauth::Services::StartWordPressRelay.call(
      client_id: @client.client_id,
      return_to: RETURN_TO,
      relay_callback_url: RELAY,
      code_challenge: CHALLENGE,
      code_challenge_method: "S256",
      site_state: "wp-csrf",
      resolve_client: ->(_id) { @client },
      state_secret: SECRET,
      **overrides
    )
  end
end
