# frozen_string_literal: true

require "test_helper"

class StartCentralRelayTest < Minitest::Test
  SECRET = "central-relay-test-secret"
  RELAY = "https://app.example.com/recording_studio_oauth/callback"
  PATTERN = "https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  RETURN_TO = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  EXACT = "https://shop.example.com/oauth/done"
  CHALLENGE = "pkce-challenge-value"

  FakeClient = Struct.new(
    :client_id,
    :api_key,
    :redirect_uris,
    :revoked,
    :use_central_relay,
    :allowed_return_patterns,
    :exact_return_urls,
    keyword_init: true
  ) do
    def revoked?
      revoked
    end

    def use_central_relay?
      use_central_relay
    end

    def redirect_uri_allowed?(uri)
      Array(redirect_uris).include?(uri)
    end

    def allows_return_to?(return_to)
      return false unless use_central_relay?

      RecordingStudioOauth::ReturnUrlRules.allow?(
        return_to,
        patterns: allowed_return_patterns,
        exact_urls: exact_return_urls
      )
    end
  end

  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
    @client = FakeClient.new(
      client_id: "app_public",
      api_key: "public",
      redirect_uris: [RELAY],
      revoked: false,
      use_central_relay: true,
      allowed_return_patterns: [PATTERN],
      exact_return_urls: [EXACT]
    )
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_happy_path_binds_return_and_uses_relay_redirect
    result = start_relay

    assert result.success?, result.error.inspect
    assert_equal RELAY, result.value.fetch(:redirect_uri)
    assert_equal "app_public", result.value.fetch(:client_id)
    assert_equal "public", result.value.fetch(:api_key)
    assert_equal CHALLENGE, result.value.fetch(:code_challenge)
    assert_equal "S256", result.value.fetch(:code_challenge_method)

    ticket = RecordingStudioOauth::CentralRelayState.parse(result.value.fetch(:state), secret: SECRET)
    assert_equal RETURN_TO, ticket.return_to
    assert_equal "site-csrf", ticket.site_state
    assert_equal CHALLENGE, ticket.code_challenge
  end

  def test_accepts_an_exact_return_url
    result = start_relay(return_to: EXACT)

    assert result.success?, result.error.inspect
    ticket = RecordingStudioOauth::CentralRelayState.parse(result.value.fetch(:state), secret: SECRET)
    assert_equal EXACT, ticket.return_to
  end

  def test_rejects_unknown_client_id
    result = start_relay(resolve_client: ->(_id) {})

    assert result.failure?
    assert_equal "invalid_client", result.error.fetch(:error)
    assert_equal "This app is not registered.", result.error.fetch(:error_description)
  end

  def test_rejects_a_return_outside_the_app_rules
    result = start_relay(return_to: "https://evil.example/steal")

    assert result.failure?
    assert_equal "invalid_request", result.error.fetch(:error)
    assert_equal "That return address is not allowed.", result.error.fetch(:error_description)
  end

  def test_rejects_clients_with_the_central_relay_off
    @client.use_central_relay = false

    result = start_relay

    assert result.failure?
    assert_equal "This app is not set up for the central relay.", result.error.fetch(:error_description)
  end

  def test_rejects_when_the_fixed_callback_is_not_registered_on_the_client
    @client.redirect_uris = [RETURN_TO]

    result = start_relay

    assert result.failure?
    assert_equal "This app is not set up for the central relay.", result.error.fetch(:error_description)
  end

  def test_requires_pkce_s256
    result = start_relay(code_challenge: nil)

    assert result.failure?
    assert_equal "Connect needs a proof key.", result.error.fetch(:error_description)
  end

  def test_ignores_a_client_supplied_redirect_and_uses_the_fixed_callback
    result = start_relay

    assert result.success?
    refute_equal RETURN_TO, result.value.fetch(:redirect_uri)
  end

  private

  def start_relay(**overrides)
    RecordingStudioOauth::Services::StartCentralRelay.call(
      client_id: @client.client_id,
      return_to: RETURN_TO,
      relay_callback_url: RELAY,
      code_challenge: CHALLENGE,
      code_challenge_method: "S256",
      site_state: "site-csrf",
      resolve_client: ->(_id) { @client },
      state_secret: SECRET,
      **overrides
    )
  end
end
