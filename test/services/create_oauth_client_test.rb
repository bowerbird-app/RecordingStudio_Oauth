# frozen_string_literal: true

require "test_helper"

class CreateOauthClientTest < Minitest::Test
  def test_redirect_uris_from_lines_strips_blanks
    uris = RecordingStudioOauth::Services::CreateOauthClient.redirect_uris_from_lines(
      " https://a.example/callback \n\nhttp://127.0.0.1/callback\n"
    )

    assert_equal ["https://a.example/callback", "http://127.0.0.1/callback"], uris
  end

  def test_confidential_from_secret_choice
    refute RecordingStudioOauth::Services::CreateOauthClient.confidential?("public")
    refute RecordingStudioOauth::Services::CreateOauthClient.confidential?(nil)
    assert RecordingStudioOauth::Services::CreateOauthClient.confidential?("has_secret")
  end
end
