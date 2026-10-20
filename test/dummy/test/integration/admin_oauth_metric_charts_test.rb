# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminOauthMetricChartsTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    travel_to Time.utc(2026, 10, 19, 12)
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

  test "admin cards count current list rows and link to matching lists" do
    happened = Time.utc(2025, 8, 20, 8)
    live, = create_oauth_client(name: "Live Grant #{SecureRandom.hex(4)}")
    approve_delegated_oauth(oauth_client: live, user: @user, access_recording: @workspace_access)
    seed_chart_rows!(happened)

    get "/admin"

    assert_response :success
    assert_includes response.body, "Self-registered apps"
    assert_includes response.body, "Connections granted"
    assert_includes response.body, "Connections revoked"

    self_registered = RecordingStudioOauth::OauthClient.active.where(self_registered: true).count
    granted = RecordingStudioOauth::OauthAuthorization.active.count
    revoked = RecordingStudioOauth::OauthAuthorization.where.not(revoked_at: nil).count

    get "/admin/sections/oauth_apps/widgets/oauth.self_registered_over_time"

    assert_response :success
    assert_includes widget_number, self_registered.to_s
    assert_includes response.body, "/admin/screens/oauth_clients"
    assert_includes response.body, "source=self_registered"
    assert_includes response.body, "Registered apps"

    get "/admin/sections/oauth_apps/widgets/oauth.granted_over_time"

    assert_response :success
    assert_includes widget_number, granted.to_s
    assert_includes response.body, "/admin/screens/oauth_connections"
    assert_includes response.body, "status=active"
    assert_includes response.body, "Connections"

    get "/admin/sections/oauth_apps/widgets/oauth.revoked_over_time"

    assert_response :success
    assert_includes widget_number, revoked.to_s
    assert_includes response.body, "/admin/screens/oauth_connections"
    assert_includes response.body, "status=revoked"

    get "/admin/screens/oauth_clients/table",
        params: { source: "self_registered", anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_equal self_registered, css_select("tbody tr, [role='row']").count { |row| row.text.include?("Self-registered") }

    get "/admin/screens/oauth_connections/table",
        params: { status: "active", anchor_url: "http://www.example.com/admin/screens/oauth_connections" }

    assert_response :success
    assert_includes response.body, "Live Grant"

    get "/admin/screens/oauth_connections/table",
        params: { status: "revoked", anchor_url: "http://www.example.com/admin/screens/oauth_connections" }

    assert_response :success
    assert_includes response.body, "DCR"
  end

  test "cards still count rows older than a twelve month timeseries window" do
    happened = Time.utc(2025, 8, 20, 8)
    seed_chart_rows!(happened)

    assert_operator RecordingStudioOauth::OauthClient.active.where(self_registered: true).count, :>=, 1
    assert_operator RecordingStudioOauth::OauthAuthorization.active.count, :>=, 0
    assert_operator RecordingStudioOauth::OauthAuthorization.where.not(revoked_at: nil).count, :>=, 1

    get "/admin/sections/oauth_apps/widgets/oauth.self_registered_over_time"

    assert_response :success
    assert_operator widget_number.to_i, :>=, 1

    get "/admin/sections/oauth_apps/widgets/oauth.revoked_over_time"

    assert_response :success
    assert_operator widget_number.to_i, :>=, 1
  end

  private

  def seed_chart_rows!(happened)
    client, = create_oauth_client(name: "DCR #{SecureRandom.hex(4)}")
    client.update!(self_registered: true, created_at: happened)
    approval = approve_delegated_oauth(
      oauth_client: client,
      user: @user,
      access_recording: @workspace_access
    )
    approval.fetch(:authorization).update!(created_at: happened, revoked_at: happened)
  end

  def widget_number
    css_select("span.text-5xl, span").find { |element|
      element["class"].to_s.include?("text-5xl")
    }&.text.to_s
  end
end
