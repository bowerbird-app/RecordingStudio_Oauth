# frozen_string_literal: true

require "test_helper"

class RegistrationPolicyTest < Minitest::Test
  Client = Struct.new(:allow_registration) do
    def allow_registration?
      allow_registration == true
    end
  end

  def setup
    @configuration = RecordingStudioOauth.configuration
    @public_origin = @configuration.public_origin
    @registration_path = @configuration.registration_path
  end

  def teardown
    @configuration.public_origin = @public_origin
    @configuration.registration_path = @registration_path
  end

  def test_client_flag_allows_registration_when_the_host_default_is_off
    client = Client.new(true)

    assert_equal true, RecordingStudioOauth::RegistrationPolicy.allowed?(client)
  end

  def test_client_flag_blocks_registration_when_the_host_default_would_allow_it
    client = Client.new(false)

    assert_equal false, RecordingStudioOauth::RegistrationPolicy.allowed?(client)
  end

  def test_unknown_client_is_closed
    assert_equal false, RecordingStudioOauth::RegistrationPolicy.allowed?(nil)
    assert_equal({ registration: false }, RecordingStudioOauth::RegistrationPolicy.payload(nil, base_url: "https://app.example.com"))
  end

  def test_open_client_includes_an_absolute_signup_url
    @configuration.public_origin = nil
    @configuration.registration_path = "/users/sign_up"
    client = Client.new(true)

    assert_equal(
      { registration: true, registration_url: "https://app.example.com/users/sign_up" },
      RecordingStudioOauth::RegistrationPolicy.payload(client, base_url: "https://app.example.com/")
    )
  end

  def test_public_origin_and_registration_path_build_the_signup_url
    @configuration.public_origin = "https://public.example.com/"
    @configuration.registration_path = "join"

    assert_equal "https://public.example.com/join", RecordingStudioOauth.registration_url(base_url: "http://internal.example")
  end

  def test_checkbox_flag_uses_the_last_submitted_value
    assert_equal true, RecordingStudioOauth::RegistrationPolicy.flag(%w[0 1])
    assert_equal false, RecordingStudioOauth::RegistrationPolicy.flag("0")
    assert_equal false, RecordingStudioOauth::RegistrationPolicy.flag(nil)
  end
end
