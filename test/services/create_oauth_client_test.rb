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

  def test_default_api_key_is_public
    assert_equal "public", RecordingStudioOauth::Services::CreateOauthClient::DEFAULT_API_KEY
    assert_equal "operations", RecordingStudioOauth::Integration::OPERATIONS_API_NAME
  end

  def test_admin_form_permits_plugin_key
    form = File.read(File.expand_path("../../lib/recording_studio_oauth/oauth_client_form.rb", __dir__))

    assert_includes form, "plugin_key"
  end

  def test_self_registration_does_not_pass_plugin_key
    register = File.read(File.expand_path("../../lib/recording_studio_oauth/services/register_oauth_client.rb", __dir__))

    refute_includes register, "plugin_key"
  end
end
