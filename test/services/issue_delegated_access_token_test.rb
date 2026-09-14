# frozen_string_literal: true

require "test_helper"

class IssueDelegatedAccessTokenTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_unknown_resource_is_invalid_target
    result = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "authorization_code",
      client_id: "client",
      resource: "https://app.example.com/unknown"
    )

    assert result.failure?
    assert_equal "invalid_target", result.error.fetch(:error)
    assert_equal "resource is not a registered protected resource", result.error.fetch(:error_description)
  end

  def test_repeated_resource_params_are_invalid_target
    result = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "authorization_code",
      client_id: "client",
      resource: [
        "https://app.example.com/recording_studio_mcp",
        "https://app.example.com/recording_studio_api/api"
      ]
    )

    assert result.failure?
    assert_equal "invalid_target", result.error.fetch(:error)
  end

  def test_public_origin_rejects_another_host_at_token_time
    RecordingStudioOauth.configuration.public_origin = "https://app.example.com"

    result = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "authorization_code",
      client_id: "client",
      resource: "https://other.example.com/recording_studio_mcp"
    )

    assert result.failure?
    assert_equal "invalid_target", result.error.fetch(:error)
  end
end
