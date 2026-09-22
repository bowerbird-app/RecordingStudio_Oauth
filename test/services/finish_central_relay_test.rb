# frozen_string_literal: true

require "test_helper"
require "uri"

class FinishCentralRelayTest < Minitest::Test
  SECRET = "central-relay-test-secret"
  PATTERN = "https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  SITE_A = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  SITE_B = "https://other.example/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  CHALLENGE_A = "challenge-site-a"
  CHALLENGE_B = "challenge-site-b"
  CODE = "rsoauth_ac_testcodevalue0123456789abcd"
  CLIENT_ID = "app_public"

  FakeCode = Struct.new(:code_challenge, :client_id)
  FakeClient = Struct.new(:client_id, :revoked, :use_central_relay, :allowed_return_patterns, :exact_return_urls, keyword_init: true) do
    def revoked?
      revoked
    end

    def use_central_relay?
      use_central_relay
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
      client_id: CLIENT_ID,
      revoked: false,
      use_central_relay: true,
      allowed_return_patterns: [PATTERN],
      exact_return_urls: []
    )
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_happy_path_returns_to_the_bound_address
    result = finish_relay(
      state: sign_state(return_to: SITE_A, challenge: CHALLENGE_A, site_state: "site-csrf"),
      code: CODE,
      find_authorization_code: ->(_code) { FakeCode.new(CHALLENGE_A, CLIENT_ID) }
    )

    assert result.success?, result.error.inspect
    assert_equal "#{SITE_A}&code=#{CODE}&state=site-csrf", result.value.fetch(:location)
  end

  def test_rejects_a_code_bound_to_another_challenge
    result = finish_relay(
      state: sign_state(return_to: SITE_B, challenge: CHALLENGE_B, site_state: "attacker"),
      code: CODE,
      find_authorization_code: ->(_code) { FakeCode.new(CHALLENGE_A, CLIENT_ID) }
    )

    assert result.failure?
    assert_equal "invalid_request", result.error.fetch(:error)
    assert_equal RecordingStudioOauth::Services::FinishCentralRelay::INVALID_RETURN, result.error.fetch(:error_description)
    assert_nil result.value
  end

  def test_rejects_a_code_issued_to_another_client
    result = finish_relay(
      state: sign_state(return_to: SITE_A, challenge: CHALLENGE_A),
      code: CODE,
      find_authorization_code: ->(_code) { FakeCode.new(CHALLENGE_A, "other_client") }
    )

    assert result.failure?
    assert_equal RecordingStudioOauth::Services::FinishCentralRelay::INVALID_RETURN, result.error.fetch(:error_description)
  end

  def test_rejects_a_relay_off_client_even_with_a_signed_return
    @client.use_central_relay = false
    result = finish_relay(
      state: sign_state(return_to: SITE_A, challenge: CHALLENGE_A),
      code: CODE,
      find_authorization_code: ->(_code) { FakeCode.new(CHALLENGE_A, CLIENT_ID) }
    )

    assert result.failure?
    assert_equal RecordingStudioOauth::Services::FinishCentralRelay::INVALID_RETURN, result.error.fetch(:error_description)
    assert_nil result.value
  end

  def test_rejects_missing_or_forged_state
    result = finish_relay(
      state: "forged",
      code: CODE,
      find_authorization_code: ->(_code) { FakeCode.new(CHALLENGE_A, CLIENT_ID) }
    )

    assert result.failure?
    assert_equal RecordingStudioOauth::Services::FinishCentralRelay::INVALID_RETURN, result.error.fetch(:error_description)
  end

  def test_does_not_redirect_an_unknown_code
    result = finish_relay(
      state: sign_state(return_to: SITE_A, challenge: CHALLENGE_A),
      code: CODE,
      find_authorization_code: ->(_code) {}
    )

    assert result.failure?
    assert_equal RecordingStudioOauth::Services::FinishCentralRelay::INVALID_RETURN, result.error.fetch(:error_description)
  end

  def test_forwards_access_denied_to_the_bound_return
    result = finish_relay(
      state: sign_state(return_to: SITE_A, challenge: CHALLENGE_A, site_state: "site-csrf"),
      error: "access_denied",
      error_description: "The resource owner denied the request"
    )

    assert result.success?
    location = result.value.fetch(:location)
    query = URI.decode_www_form(URI.parse(location).query).to_h
    assert_equal SITE_A.split("?").first, location.split("?").first
    assert_equal "recording_studio_oauth_callback", query.fetch("action")
    assert_equal "access_denied", query.fetch("error")
    assert_equal "site-csrf", query.fetch("state")
    refute query.key?("code")
  end

  private

  def sign_state(return_to:, challenge:, site_state: nil)
    RecordingStudioOauth::CentralRelayState.new(
      return_to: return_to,
      client_id: CLIENT_ID,
      code_challenge: challenge,
      site_state: site_state
    ).sign(secret: SECRET)
  end

  def finish_relay(**overrides)
    RecordingStudioOauth::Services::FinishCentralRelay.call(
      state: nil,
      state_secret: SECRET,
      resolve_client: ->(_id) { @client },
      **overrides
    )
  end
end
