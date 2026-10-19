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
    client, = create_oauth_client(name: "DCR #{SecureRandom.hex(4)}")
    happened = Time.utc(2026, 10, 19, 8)
    client.update!(self_registered: true, created_at: happened)
    approval = approve_delegated_oauth(
      oauth_client: client,
      user: @user,
      access_recording: @workspace_access
    )
    approval.fetch(:authorization).update!(created_at: happened, revoked_at: happened)

    get "/admin"

    assert_response :success
    assert_includes response.body, "Self-registered apps"
    assert_includes response.body, "Connections granted"
    assert_includes response.body, "Connections revoked"
    assert_includes response.body, "Apps that signed themselves up, counted on the day they appeared."
    assert_includes response.body, "New connections by day. Revoked ones still count here."
    assert_includes response.body, "Connections ended that day."

    %w[oauth.self_registered_over_time oauth.granted_over_time oauth.revoked_over_time].each do |widget_key|
      get "/admin/sections/root/widgets/#{widget_key}"

      assert_response :success, widget_key
      assert_includes response.body, "/admin/screens/oauth_clients"
      assert_includes response.body, "Registered apps"
    end

    get "/admin/sections/oauth_apps/widgets/oauth.self_registered_over_time"

    assert_response :success
    assert_includes response.body, "/admin/screens/oauth_clients"

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
  end

  private

  def metrics_admin_context
    Struct.new(:current_actor, :timezone).new(@user, "UTC")
  end

  def series_value(series, date)
    points = series.fetch(0).fetch(:data)
    pair = points.find { |point| point[0].to_s == date }
    pair ? pair[1].to_i : 0
  end
end
