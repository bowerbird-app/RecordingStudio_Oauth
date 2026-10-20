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

  def test_oauth_apps_section_puts_counts_on_the_first_row
    usages = RecordingStudioOauth::Admin::OauthAppsSection.widget_usages

    assert_equal %w[oauth.active_apps oauth.active_connections], usages.first(2).map(&:key)
    assert_equal %i[compact compact], usages.first(2).map(&:view_variant)
    assert_equal(
      %w[oauth.self_registered_over_time oauth.granted_over_time oauth.revoked_over_time],
      usages.drop(2).map(&:key)
    )
    assert_nil(usages.drop(2).map(&:view_variant).compact.first)
  end

  def test_metric_chart_widgets_link_to_matching_lists_and_read_metrics
    RecordingStudioOauth::Admin::MetricChartWidgets::SPECS.each do |spec|
      widget = RecordingStudioAdmin.widget_for(spec.fetch(:key))

      refute_nil widget, "expected #{spec.fetch(:key)} to be registered"
      assert_equal :chart, widget.type
      assert_equal :area, widget.chart_type
      assert_equal spec.fetch(:title), widget.title
      assert_equal spec.fetch(:info), widget.info
      assert_equal expected_path(spec), widget.link_to.call(admin_context)
      assert_equal spec.fetch(:link_label), widget.link_label
      assert_equal :site, widget.blast_radius
      assert_equal "Last 12 months", RecordingStudioOauth::Admin::MetricChartWidgets::PERIOD_LABEL

      result = RecordingStudioMetrics::Result.new(
        metric: spec.fetch(:metric),
        type: :timeseries,
        title: spec.fetch(:title),
        data: [{ date: "2026-10-19", value: 1 }]
      )
      series = RecordingStudioMetrics.stub(:execute, result) do
        RecordingStudioOauth::Admin::MetricChartWidgets.series(spec.fetch(:metric), admin_context)
      end

      assert_equal spec.fetch(:title), series.fetch(0).fetch(:name)
      assert_equal [{ x: "2026-10-19", y: 1 }], series.fetch(0).fetch(:data)
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

      assert_equal [{ name: "New self-registered apps", data: [{ x: "2026-10-19", y: 2 }] }], series
    end

    assert_equal "oauth_clients.self_registered_over_time", captured[0]
    assert_equal :day, captured[1][:interval]
    assert_in_delta 365.days.ago.to_f, captured[1][:start_at].to_f, 2
    assert captured[1][:context].site_authorized?
    assert_equal :site, captured[1][:context].scope
  end

  def test_chart_headlines_use_table_scopes
    charts = File.read(File.expand_path("../lib/recording_studio_oauth/admin/metric_chart_widgets.rb", __dir__))

    assert_includes charts, "RecordingStudioMetrics::Admin.chart_series"
    assert_includes charts, "365.days"
    assert_includes charts, "OauthClient.active.where(self_registered: true)"
    assert_includes charts, "OauthAuthorization.active.count"
    assert_includes charts, "OauthAuthorization.where.not(revoked_at: nil)"
  end

  def test_chart_headline_uses_table_scope_not_series_total
    widget = RecordingStudioAdmin.widget_for("oauth.granted_over_time")
    charts = File.read(File.expand_path("../lib/recording_studio_oauth/admin/metric_chart_widgets.rb", __dir__))

    assert_equal :chart, widget.type
    refute_includes charts, "MetricChartWidgets.total(metric, context)"
    assert_includes charts, "spec.fetch(:count).call"
  end

  private

  def expected_path(spec)
    RecordingStudioOauth::Admin::OauthClientsFilters.screen_path(
      admin_context,
      spec.fetch(:link_params),
      screen: spec.fetch(:screen)
    )
  end

  def admin_context
    actor = Object.new
    Struct.new(:current_actor, :timezone) do
      def admin_screen_path(key)
        "/admin/screens/#{key}"
      end
    end.new(actor, "UTC")
  end
end
