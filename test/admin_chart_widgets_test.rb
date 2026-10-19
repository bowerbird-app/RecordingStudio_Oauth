# frozen_string_literal: true

require "test_helper"

class AdminChartWidgetsTest < Minitest::Test
  def setup
    RecordingStudioOauth::Admin.register!
  end

  def test_oauth_apps_section_lists_metric_chart_widgets
    keys = RecordingStudioOauth::Admin::OauthAppsSection.widget_keys

    assert_includes keys, "oauth.active_apps"
    assert_includes keys, "oauth.active_connections"
    assert_includes keys, "oauth.self_registered_over_time"
    assert_includes keys, "oauth.granted_over_time"
    assert_includes keys, "oauth.revoked_over_time"
  end

  def test_metric_chart_widgets_link_to_registered_apps_and_read_metrics
    RecordingStudioOauth::Admin::MetricChartWidgets::SPECS.each do |spec|
      widget = RecordingStudioAdmin.widget_for(spec.fetch(:key))

      refute_nil widget, "expected #{spec.fetch(:key)} to be registered"

      result = RecordingStudioMetrics::Result.new(
        metric: spec.fetch(:metric),
        type: :timeseries,
        title: spec.fetch(:title),
        data: [{ date: "2026-10-19", value: 1 }]
      )
      resolved = RecordingStudioMetrics.stub(:execute, result) do
        widget.resolve(admin_context)
      end

      assert_equal :chart, resolved.type
      assert_equal :area, resolved.chart_type
      assert_equal spec.fetch(:title), resolved.title
      assert_equal spec.fetch(:info), resolved.info
      assert_equal "/admin/screens/oauth_clients", resolved.link_to
      assert_equal "Registered apps", resolved.link_label
      assert_equal :site, widget.blast_radius
      assert_equal spec.fetch(:title), resolved.series.fetch(0).fetch(:name)
    end
  end

  def test_metric_chart_series_reads_recording_studio_metrics_with_site_scope
    captured = nil
    result = RecordingStudioMetrics::Result.new(
      metric: "oauth_clients.self_registered_over_time",
      type: :timeseries,
      title: "New self-registered apps",
      data: [{ date: "2026-10-19", value: 2 }]
    )

    RecordingStudioMetrics.stub(:execute, lambda { |identifier, **kwargs|
      captured = [identifier, kwargs]
      result
    }) do
      series = RecordingStudioOauth::Admin::MetricChartWidgets.series(
        "oauth_clients.self_registered_over_time",
        admin_context
      )

      assert_equal [{ name: "New self-registered apps", data: [["2026-10-19", 2]] }], series
    end

    assert_equal "oauth_clients.self_registered_over_time", captured[0]
    assert_equal :day, captured[1][:interval]
    assert captured[1][:context].site_authorized?
    assert_equal :site, captured[1][:context].scope
  end

  private

  def admin_context
    actor = Object.new
    Struct.new(:current_actor, :timezone) do
      def admin_screen_path(key)
        "/admin/screens/#{key}"
      end
    end.new(actor, "UTC")
  end
end
