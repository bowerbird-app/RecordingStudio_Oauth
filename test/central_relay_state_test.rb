# frozen_string_literal: true

require "test_helper"

class CentralRelayStateTest < Minitest::Test
  SECRET = "central-relay-test-secret"
  RETURN_TO = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"

  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_round_trip_preserves_return_binding
    ticket = RecordingStudioOauth::CentralRelayState.new(
      return_to: RETURN_TO,
      client_id: "client_123",
      code_challenge: "challenge_abc",
      site_state: "site-csrf"
    )
    parsed = RecordingStudioOauth::CentralRelayState.parse(ticket.sign(secret: SECRET), secret: SECRET)

    assert_equal RETURN_TO, parsed.return_to
    assert_equal "client_123", parsed.client_id
    assert_equal "challenge_abc", parsed.code_challenge
    assert_equal "site-csrf", parsed.site_state
  end

  def test_rejects_tampered_or_wrong_secret_state
    token = RecordingStudioOauth::CentralRelayState.new(
      return_to: RETURN_TO,
      client_id: "client_123",
      code_challenge: "challenge_abc"
    ).sign(secret: SECRET)

    assert_nil RecordingStudioOauth::CentralRelayState.parse("#{token}x", secret: SECRET)
    assert_nil RecordingStudioOauth::CentralRelayState.parse(token, secret: "other-secret")
    assert_nil RecordingStudioOauth::CentralRelayState.parse("", secret: SECRET)
  end

  def test_expired_state_is_rejected
    token = RecordingStudioOauth::CentralRelayState.new(
      return_to: RETURN_TO,
      client_id: "client_123",
      code_challenge: "challenge_abc"
    ).sign(secret: SECRET, expires_in: -1)

    assert_nil RecordingStudioOauth::CentralRelayState.parse(token, secret: SECRET)
  end

  def test_rejects_an_unsafe_return_inside_a_signed_ticket
    token = RecordingStudioOauth::CentralRelayState.new(
      return_to: "javascript:alert(1)",
      client_id: "client_123",
      code_challenge: "challenge_abc"
    ).sign(secret: SECRET)

    assert_nil RecordingStudioOauth::CentralRelayState.parse(token, secret: SECRET)
  end
end
