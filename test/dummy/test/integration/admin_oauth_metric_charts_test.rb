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

  test "admin dashboard charts oauth metrics and links to registered apps" do
    happened = Time.utc(2026, 10, 19, 8)
    seed_chart_rows!(happened)

    get "/admin"

    assert_response :success
    assert_includes response.body, "Self-registered apps"
    assert_includes response.body, "Connections granted"
    assert_includes response.body, "Connections revoked"
    assert_includes response.body, "min-h-28"
    assert_includes response.body, "Last 12 months"
    assert_operator response.body.scan("grid-cols-1 md:grid-cols-2 lg:grid-cols-3").size, :>=, 2

    %w[oauth.self_registered_over_time oauth.granted_over_time oauth.revoked_over_time].each do |widget_key|
      get "/admin/sections/root/widgets/#{widget_key}"

      assert_response :success, widget_key
      assert_includes response.body, "/admin/screens/oauth_clients"
      assert_includes response.body, "Registered apps"
      assert_includes response.body, "2026-10-19"
    end

    get "/admin/sections/oauth_apps"

    assert_response :success
    assert_includes response.body, "min-h-28"
    assert_includes response.body, "Self-registered apps"

    series = RecordingStudioOauth::Admin::MetricChartWidgets.series(
      "oauth_clients.self_registered_over_time",
      metrics_admin_context
    )
    granted = RecordingStudioOauth::Admin::MetricChartWidgets.series(
      "oauth_authorizations.granted_over_time",
      metrics_admin_context
    )
    revoked = RecordingStudioOauth::Admin::MetricChartWidgets.series(
      "oauth_authorizations.revoked_over_time",
      metrics_admin_context
    )

    assert_operator series_value(series, "2026-10-19"), :>=, 1
    assert_operator series_value(granted, "2026-10-19"), :>=, 1
    assert_operator series_value(revoked, "2026-10-19"), :>=, 1
    assert_equal series_value(series, "2026-10-19"),
                 RecordingStudioOauth::OauthClient.where(self_registered: true, created_at: Time.utc(2026, 10, 19)...Time.utc(2026, 10, 20)).count
  end

  test "chart widgets include rows older than the default thirty day metric window" do
    happened = Time.utc(2026, 8, 20, 8)
    seed_chart_rows!(happened)

    series = RecordingStudioOauth::Admin::MetricChartWidgets.series(
      "oauth_clients.self_registered_over_time",
      metrics_admin_context
    )
    granted = RecordingStudioOauth::Admin::MetricChartWidgets.series(
      "oauth_authorizations.granted_over_time",
      metrics_admin_context
    )
    revoked = RecordingStudioOauth::Admin::MetricChartWidgets.series(
      "oauth_authorizations.revoked_over_time",
      metrics_admin_context
    )

    assert_operator series_value(series, "2026-08-20"), :>=, 1
    assert_operator series_value(granted, "2026-08-20"), :>=, 1
    assert_operator series_value(revoked, "2026-08-20"), :>=, 1
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

  def metrics_admin_context
    Struct.new(:current_actor, :timezone).new(@user, "UTC")
  end

  def series_value(series, date)
    points = series.fetch(0).fetch(:data)
    point = points.find { |entry| entry[:x].to_s == date }
    point ? point[:y].to_i : 0
  end
end
