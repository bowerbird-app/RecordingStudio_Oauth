# frozen_string_literal: true

require "test_helper"

class WordPressRelayTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_default_paths_under_oauth_mount
    assert_equal "/recording_studio_oauth/wordpress/connect", RecordingStudioOauth::WordPressRelay.connect_path
    assert_equal "/recording_studio_oauth/wordpress/callback", RecordingStudioOauth::WordPressRelay.callback_path
    assert_equal(
      "https://app.example.com/recording_studio_oauth/wordpress/callback",
      RecordingStudioOauth.wordpress_relay_callback_url(base_url: "https://app.example.com/")
    )
    assert_equal(
      "https://app.example.com/recording_studio_oauth/wordpress/connect",
      RecordingStudioOauth.wordpress_relay_connect_url(base_url: "https://app.example.com")
    )
  end

  def test_paths_follow_engine_mount_path
    RecordingStudioOauth.configuration.engine_mount_path = "/oauth"

    assert_equal "/oauth/wordpress/callback", RecordingStudioOauth::WordPressRelay.callback_path
  end
end
