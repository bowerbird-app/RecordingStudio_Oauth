# frozen_string_literal: true

require "test_helper"

class TokenAuthenticatorTest < Minitest::Test
  def test_register_pins_the_authenticator_once
    RecordingStudioOauth::TokenAuthenticator.register!
    RecordingStudioOauth::TokenAuthenticator.register!

    authenticators = RecordingStudioApi.token_authenticators
    assert_equal 1, authenticators.count { |item| item == RecordingStudioOauth::TokenAuthenticator }
  end

  def test_valid_format_accepts_oauth_access_tokens
    assert RecordingStudioOauth::TokenAuthenticator.valid_format?("rsoauth_at_#{'a' * 43}")
    refute RecordingStudioOauth::TokenAuthenticator.valid_format?("rsapi_at_#{'a' * 43}")
  end
end
