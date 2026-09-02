# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminOauthAppsTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    create_access_recording_for(user: @user)
    _admin_root, @admin_root_recording = create_admin_root_recording
    grant_or_bootstrap_access!(recording: @admin_root_recording, actor: @user, role: :admin)
    RecordingStudioOauth::OauthClient.find_or_create_by!(name: "Seed Demo App") do |client|
      client.redirect_uris = ["http://127.0.0.1/callback"]
      client.confidential = false
      client.api_key = "public"
    end
    sign_in @user
    switch_to_root!(@admin_root_recording)
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "staff admin shows registered apps after switching to Admin" do
    get "/admin"

    assert_response :success
    assert_includes response.body, "Admin"
    assert_includes response.body, "Registered apps"
    assert_includes response.body, "Active connections"
  end

  test "staff admin registered apps screen lists the client" do
    get "/admin/screens/oauth_clients"

    assert_response :success
    assert_includes response.body, "Registered apps"

    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_includes response.body, "Seed Demo App"
    assert_includes response.body, "Public"
    assert_includes response.body, "Active"
    assert_includes response.body, "Revoke"
  end
end
