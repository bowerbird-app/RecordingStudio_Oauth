# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ConnectedAppsTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    _root, @access_recording = create_access_recording_for(user: @user)
    @oauth_client, = create_oauth_client(name: "Notes App")
    @approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording
    )
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "lists connected apps without a root switcher" do
    get recording_studio_oauth.connected_apps_path

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "title", text: /Connected apps/
    assert_includes response.body, "Notes App"
    assert_select "[role='list']"
    assert_select "[role='listitem']"
    assert_includes response.body, "Remove access"
    assert_select "[data-controller='recording-studio-root-switchable--root-switch-dropdown']", count: 0
    assert_not_includes response.body, "Sign out"
  end

  test "revokes a connected app" do
    delete recording_studio_oauth.connected_app_path(@approved.fetch(:authorization))

    assert_redirected_to recording_studio_oauth.connected_apps_path
    authorization = @approved.fetch(:authorization).reload
    assert_not_nil authorization.revoked_at
    assert_not_nil authorization.access_recording.reload.trashed_at
  end
end
