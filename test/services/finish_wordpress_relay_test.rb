# frozen_string_literal: true

require "test_helper"
require "uri"

class FinishWordPressRelayTest < Minitest::Test
  SECRET = "wordpress-relay-test-secret"
  SITE_A = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  SITE_B = "https://evil.example/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  CHALLENGE_A = "challenge-site-a"
  CHALLENGE_B = "challenge-site-b"
  CODE = "rsoauth_ac_testcodevalue0123456789abcd"

  FakeCode = Struct.new(:code_challenge)

  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_happy_path_returns_to_bound_wordpress_callback
    result = finish_relay(
      state: sign_state(return_to: SITE_A, challenge: CHALLENGE_A, site_state: "wp-csrf"),
      code: CODE,
      find_authorization_code: ->(_code) { FakeCode.new(CHALLENGE_A) }
    )

    assert result.success?, result.error.inspect
    assert_equal "#{SITE_A}&code=#{CODE}&state=wp-csrf", result.value.fetch(:location)
  end

  def test_rejects_code_handed_to_another_site_state
    result = finish_relay(
      state: sign_state(return_to: SITE_B, challenge: CHALLENGE_B, site_state: "attacker"),
      code: CODE,
      find_authorization_code: ->(_code) { FakeCode.new(CHALLENGE_A) }
    )

    assert result.failure?
    assert_equal "invalid_request", result.error.fetch(:error)
    assert_equal RecordingStudioOauth::Services::FinishWordPressRelay::INVALID_RETURN, result.error.fetch(:error_description)
    assert_nil result.value
  end

  def test_rejects_missing_or_forged_state
    result = finish_relay(
      state: "forged",
      code: CODE,
      find_authorization_code: ->(_code) { FakeCode.new(CHALLENGE_A) }
    )

    assert result.failure?
    assert_equal RecordingStudioOauth::Services::FinishWordPressRelay::INVALID_RETURN, result.error.fetch(:error_description)
  end

  def test_does_not_redirect_unknown_code_even_with_valid_state
    result = finish_relay(
      state: sign_state(return_to: SITE_A, challenge: CHALLENGE_A),
      code: CODE,
      find_authorization_code: ->(_code) {}
    )

    assert result.failure?
    assert_equal RecordingStudioOauth::Services::FinishWordPressRelay::INVALID_RETURN, result.error.fetch(:error_description)
  end

  def test_forwards_access_denied_to_bound_return
    result = finish_relay(
      state: sign_state(return_to: SITE_A, challenge: CHALLENGE_A, site_state: "wp-csrf"),
      error: "access_denied",
      error_description: "The resource owner denied the request"
    )

    assert result.success?
    location = result.value.fetch(:location)
    query = URI.decode_www_form(URI.parse(location).query).to_h
    assert_equal SITE_A.split("?").first, location.split("?").first
    assert_equal "recording_studio_oauth_callback", query.fetch("action")
    assert_equal "access_denied", query.fetch("error")
    assert_equal "wp-csrf", query.fetch("state")
    refute query.key?("code")
  end

  private

  def sign_state(return_to:, challenge:, site_state: nil)
    RecordingStudioOauth::WordPressRelayState.new(
      return_to: return_to,
      client_id: "wp_public",
      code_challenge: challenge,
      site_state: site_state
    ).sign(secret: SECRET)
  end

  def finish_relay(**overrides)
    RecordingStudioOauth::Services::FinishWordPressRelay.call(
      state: nil,
      state_secret: SECRET,
      **overrides
    )
  end
end
