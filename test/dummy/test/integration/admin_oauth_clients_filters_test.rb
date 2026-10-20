# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminOauthClientsFiltersTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    _workspace_root, @workspace_access = create_access_recording_for(user: @user)
    _admin_root, @admin_root_recording = create_admin_root_recording
    grant_or_bootstrap_access!(recording: @admin_root_recording, actor: @user, role: :admin)
    sign_in @user
    switch_to_root!(@admin_root_recording)
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "registered apps screen offers source status and host API filters inline" do
    get "/admin/screens/oauth_clients"

    assert_response :success
    assert_includes response.body, "name=\"source\""
    assert_includes response.body, "name=\"status\""
    assert_includes response.body, "name=\"api_key\""
    assert_includes response.body, "staff"
    assert_includes response.body, "self_registered"
    assert_includes response.body, "active"
    assert_includes response.body, "revoked"
    assert_includes response.body, "public"
    assert_includes response.body, "operations"
    assert_includes response.body, 'data-recording-studio-admin--screen-filters-modal-filters-value="false"'
    assert_includes response.body, 'id="screen-filters-form"'
    refute_includes response.body, "screen-inline-filters-form"
  end

  test "new app is a secondary button" do
    get "/admin/screens/oauth_clients"

    assert_response :success
    button = css_select("a, button").find { |element| element.text.strip == "New app" }

    refute_nil button, "expected a New app control"
    assert_equal "secondary", button["data-fp-style"]
    refute_equal "primary", button["data-fp-style"]
  end

  test "status defaults to active and can show revoked" do
    active, = create_oauth_client(name: "Live App")
    revoked, = create_oauth_client(name: "Dead App")
    revoked.revoke!

    get_table

    assert_includes response.body, active.name
    refute_includes response.body, revoked.name

    get_table(status: "revoked")

    assert_includes response.body, revoked.name
    refute_includes response.body, active.name
  end

  test "source filter splits staff and self-registered apps" do
    staff, = create_oauth_client(name: "Staff List App")
    dcr, = create_oauth_client(name: "DCR List App")
    dcr.update!(self_registered: true)

    get_table(source: "self_registered")

    assert_includes response.body, dcr.name
    refute_includes response.body, staff.name

    get_table(source: "staff")

    assert_includes response.body, staff.name
    refute_includes response.body, dcr.name
  end

  test "api filter uses host registered APIs" do
    public_app, = create_oauth_client(name: "Public List App", api: "public")
    ops_app, = create_oauth_client(name: "Ops List App", api: "operations")

    get_table(api_key: "operations")

    assert_includes response.body, ops_app.name
    refute_includes response.body, public_app.name
  end

  test "granted and revoked widgets open connections with matching status" do
    granted_client, = create_oauth_client(name: "Granted List App")
    revoked_client, = create_oauth_client(name: "Revoked List App")
    unused, = create_oauth_client(name: "Quiet List App")
    old, = create_oauth_client(name: "Old Grant App")

    approve_delegated_oauth(oauth_client: granted_client, user: @user, access_recording: @workspace_access)
    revoked = approve_delegated_oauth(
      oauth_client: revoked_client,
      user: @user,
      access_recording: @workspace_access
    ).fetch(:authorization)
    RecordingStudioOauth::Services::VoidOauthAuthorization.call(authorization: revoked)

    old_grant = approve_delegated_oauth(
      oauth_client: old,
      user: @user,
      access_recording: @workspace_access
    ).fetch(:authorization)
    old_grant.update!(created_at: 400.days.ago, revoked_at: 400.days.ago)

    get "/admin/sections/oauth_apps/widgets/oauth.granted_over_time"

    assert_response :success
    assert_includes response.body, "/admin/screens/oauth_connections"
    assert_includes response.body, "status=active"
    refute_includes response.body, "status=revoked"

    get "/admin/sections/oauth_apps/widgets/oauth.revoked_over_time"

    assert_response :success
    assert_includes response.body, "/admin/screens/oauth_connections"
    assert_includes response.body, "status=revoked"

    get_connections_table

    assert_includes response.body, granted_client.name
    refute_includes response.body, revoked_client.name
    refute_includes response.body, unused.name

    get_connections_table(status: "revoked")

    assert_includes response.body, revoked_client.name
    refute_includes response.body, granted_client.name
    refute_includes response.body, unused.name
    assert_includes response.body, old.name

    get_table(connections: "granted")

    assert_includes response.body, granted_client.name
    assert_includes response.body, revoked_client.name
    refute_includes response.body, unused.name
    refute_includes response.body, old.name

    get_table(connections: "revoked")

    assert_includes response.body, revoked_client.name
    refute_includes response.body, granted_client.name
    refute_includes response.body, unused.name
    refute_includes response.body, old.name
  end

  private

  def get_table(extra = {})
    get "/admin/screens/oauth_clients/table",
        params: extra.merge(anchor_url: "http://www.example.com/admin/screens/oauth_clients")
    assert_response :success
  end

  def get_connections_table(extra = {})
    get "/admin/screens/oauth_connections/table",
        params: extra.merge(anchor_url: "http://www.example.com/admin/screens/oauth_connections")
    assert_response :success
  end
end
