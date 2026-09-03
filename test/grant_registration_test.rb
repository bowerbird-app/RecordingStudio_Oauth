# frozen_string_literal: true

require "test_helper"

class GrantRegistrationTest < Minitest::Test
  def test_register_pins_authorization_code_and_refresh_token
    RecordingStudioOauth::GrantRegistration.register!

    grants = RecordingStudioApi.oauth_grants
    assert_equal RecordingStudioOauth::DelegatedGrant, grants.fetch("authorization_code")
    assert_equal RecordingStudioOauth::DelegatedGrant, grants.fetch("refresh_token")
    refute grants.key?("client_credentials")
  end

  def test_delegated_grant_maps_api_params_onto_the_domain_service
    captured = nil
    RecordingStudioOauth::Services::IssueDelegatedAccessToken.stub(
      :call,
      lambda do |**kwargs|
        captured = kwargs
        Struct.new(:success?).new(true)
      end
    ) do
      RecordingStudioOauth::DelegatedGrant.call(
        grant_type: "authorization_code",
        params: { "code" => "abc", "redirect_uri" => "http://127.0.0.1/callback", "code_verifier" => "verifier" },
        client_id: "client-1",
        client_secret: nil,
        api: "public"
      )
    end

    assert_equal "authorization_code", captured.fetch(:grant_type)
    assert_equal "client-1", captured.fetch(:client_id)
    assert_equal "public", captured.fetch(:api)
    assert_equal "abc", captured.fetch(:code)
    assert_equal "http://127.0.0.1/callback", captured.fetch(:redirect_uri)
    assert_equal "verifier", captured.fetch(:code_verifier)
  end
end
