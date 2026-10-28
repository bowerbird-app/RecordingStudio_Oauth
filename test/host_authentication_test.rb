# frozen_string_literal: true

require "test_helper"

class HostAuthenticationTest < Minitest::Test
  def test_uses_accessible_controller_auth
    source = File.read(File.expand_path("../app/controllers/recording_studio_oauth/concerns/host_authentication.rb", __dir__))

    assert_includes source, "RecordingStudioAccessible::ControllerAuth"
    assert_includes source, "recording_studio_auth("
    assert_includes source, "config: -> { RecordingStudioOauth.configuration }"
    assert_includes source, "prefix: :oauth"
    assert_includes source, "authenticate_method: :authenticate_host_user!"
    assert_includes source, "actor_method: :current_oauth_actor"
    refute_includes source, "def authenticate_host_user!"
    refute_includes source, "def current_oauth_actor"
    refute_includes source, "Current.actor ="
  end
end
