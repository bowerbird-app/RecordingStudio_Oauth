# frozen_string_literal: true

require "test_helper"

class OauthErrorMapperTest < Minitest::Test
  def test_hash_payload_passes_through
    payload = RecordingStudioOauth::OauthErrorMapper.payload_for(
      error: "invalid_grant",
      error_description: "nope"
    )

    assert_equal "invalid_grant", payload.fetch(:error)
    assert_equal :bad_request, RecordingStudioOauth::OauthErrorMapper.status_for(payload)
  end

  def test_unknown_error_is_server_error
    payload = RecordingStudioOauth::OauthErrorMapper.payload_for("boom")

    assert_equal "server_error", payload.fetch(:error)
    assert_equal :internal_server_error, RecordingStudioOauth::OauthErrorMapper.status_for(payload)
  end

  def test_invalid_client_is_unauthorized
    payload = { error: "invalid_client", error_description: "no" }

    assert_equal :unauthorized, RecordingStudioOauth::OauthErrorMapper.status_for(payload)
  end
end
