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
    assert_includes response.body, "New app"
    assert_includes response.body, "/recording_studio_oauth/admin/oauth_clients/new"

    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_includes response.body, "Seed Demo App"
    assert_includes response.body, "Public"
    assert_includes response.body, "Active"
    assert_includes response.body, "Revoke"
    refute_match(/rsoauth_cs_/, response.body)
  end

  test "staff can open the new app form" do
    get "/recording_studio_oauth/admin/oauth_clients/new"

    assert_response :success
    assert_includes response.body, "New app"
    assert_includes response.body, "Name"
    assert_includes response.body, "Redirect URLs"
    assert_includes response.body, "Secret"
    assert_includes response.body, "Create app"
    refute_includes response.body, "max-w-sm"
  end

  test "staff can create a public app and see the client id once without a secret" do
    assert_difference -> { RecordingStudioOauth::OauthClient.count }, 1 do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Staff Public App",
          redirect_uris: "http://127.0.0.1/callback",
          secret: "public"
        }
      }
    end

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Staff Public App")
    assert_redirected_to "/recording_studio_oauth/admin/oauth_clients/#{client.id}"
    follow_redirect!

    assert_response :success
    assert_includes response.body, "App credentials"
    assert_includes response.body, client.client_id
    assert_includes response.body, "This app has no secret."
    refute_match(/rsoauth_cs_/, response.body)
    refute client.confidential?
    assert_nil client.client_secret_digest

    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_includes response.body, "Staff Public App"
    assert_includes response.body, "Public"
    refute_includes response.body, client.client_id
    refute_match(/rsoauth_cs_/, response.body)
  end

  test "staff can create a confidential app and see the secret only once" do
    assert_difference -> { RecordingStudioOauth::OauthClient.count }, 1 do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Staff Secret App",
          redirect_uris: "https://example.com/callback\n",
          secret: "has_secret"
        }
      }
    end

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Staff Secret App")
    follow_redirect!

    assert_response :success
    assert_includes response.body, client.client_id
    secret = response.body[/\brsoauth_cs_[A-Za-z0-9_-]+\b/]
    assert_predicate secret, :present?
    assert client.confidential?
    assert client.authenticate_secret?(secret)

    get "/recording_studio_oauth/admin/oauth_clients/#{client.id}"

    assert_response :success
    assert_includes response.body, client.client_id
    refute_includes response.body, secret
    assert_includes response.body, "The secret was shown once."

    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_includes response.body, "Staff Secret App"
    assert_includes response.body, "Has a secret"
    refute_includes response.body, secret
  end

  test "staff create rejects a redirect URL with a fragment" do
    assert_no_difference -> { RecordingStudioOauth::OauthClient.count } do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Bad Redirect App",
          redirect_uris: "https://example.com/callback#fragment",
          secret: "public"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "New app"
  end

  test "staff can still revoke a registered app" do
    client = RecordingStudioOauth::OauthClient.find_by!(name: "Seed Demo App")

    post "/recording_studio_oauth/admin/oauth_clients/#{client.id}/revoke"

    assert_response :redirect
    assert_predicate client.reload, :revoked?
  end

  test "create is forbidden without admin access" do
    outsider = create_user
    create_access_recording_for(user: outsider)
    sign_in outsider

    get "/recording_studio_oauth/admin/oauth_clients/new"

    assert_response :forbidden

    assert_no_difference -> { RecordingStudioOauth::OauthClient.count } do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Blocked App",
          redirect_uris: "http://127.0.0.1/callback",
          secret: "public"
        }
      }
    end

    assert_response :forbidden
  end
end
