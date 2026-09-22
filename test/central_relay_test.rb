# frozen_string_literal: true

require "test_helper"

class CentralRelayTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_default_paths_under_oauth_mount
    assert_equal "/recording_studio_oauth/connect", RecordingStudioOauth::CentralRelay.connect_path
    assert_equal "/recording_studio_oauth/callback", RecordingStudioOauth::CentralRelay.callback_path
    assert_equal(
      "https://app.example.com/recording_studio_oauth/callback",
      RecordingStudioOauth.central_relay_callback_url(base_url: "https://app.example.com/")
    )
    assert_equal(
      "https://app.example.com/recording_studio_oauth/connect",
      RecordingStudioOauth.central_relay_connect_url(base_url: "https://app.example.com")
    )
  end

  def test_paths_follow_engine_mount_path
    RecordingStudioOauth.configuration.engine_mount_path = "/oauth"

    assert_equal "/oauth/callback", RecordingStudioOauth::CentralRelay.callback_path
  end

  def test_wordpress_paths_are_not_routed
    routes = File.read(File.expand_path("../config/routes.rb", __dir__))

    refute_includes routes, "wordpress"
    assert_includes routes, 'get "/connect"'
    assert_includes routes, 'to: "central_relays#start"'
    assert_includes routes, 'get "/callback"'
    assert_includes routes, 'to: "central_relays#callback"'
    refute RecordingStudioOauth.respond_to?(:wordpress_relay_callback_url)
    refute RecordingStudioOauth.respond_to?(:wordpress_relay_connect_url)
    refute_includes routes, "wordpress_relays"
  end
end
