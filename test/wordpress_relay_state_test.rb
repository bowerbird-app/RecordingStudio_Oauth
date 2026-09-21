# frozen_string_literal: true

require "test_helper"

class WordPressRelayStateTest < Minitest::Test
  SECRET = "wordpress-relay-test-secret"
  RETURN_TO = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"

  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_round_trip_preserves_return_binding
    ticket = RecordingStudioOauth::WordPressRelayState.new(
      return_to: RETURN_TO,
      client_id: "client_123",
      code_challenge: "challenge_abc",
      site_state: "wp-csrf"
    )
    parsed = RecordingStudioOauth::WordPressRelayState.parse(ticket.sign(secret: SECRET), secret: SECRET)

    assert_equal RETURN_TO, parsed.return_to
    assert_equal "client_123", parsed.client_id
    assert_equal "challenge_abc", parsed.code_challenge
    assert_equal "wp-csrf", parsed.site_state
  end

  def test_rejects_tampered_or_wrong_secret_state
    token = RecordingStudioOauth::WordPressRelayState.new(
      return_to: RETURN_TO,
      client_id: "client_123",
      code_challenge: "challenge_abc"
    ).sign(secret: SECRET)

    assert_nil RecordingStudioOauth::WordPressRelayState.parse("#{token}x", secret: SECRET)
    assert_nil RecordingStudioOauth::WordPressRelayState.parse(token, secret: "other-secret")
    assert_nil RecordingStudioOauth::WordPressRelayState.parse("", secret: SECRET)
  end

  def test_expired_state_is_rejected
    token = RecordingStudioOauth::WordPressRelayState.new(
      return_to: RETURN_TO,
      client_id: "client_123",
      code_challenge: "challenge_abc"
    ).sign(secret: SECRET, expires_in: -1)

    assert_nil RecordingStudioOauth::WordPressRelayState.parse(token, secret: SECRET)
  end
end
