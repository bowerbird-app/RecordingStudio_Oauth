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

  def test_count_widgets_link_to_matching_lists
    RecordingStudioOauth::Admin::MetricChartWidgets::SPECS.each do |spec|
      widget = RecordingStudioAdmin.widget_for(spec.fetch(:key))

      refute_nil widget, "expected #{spec.fetch(:key)} to be registered"

      assert_equal :number, widget.type
      assert_equal spec.fetch(:title), widget.title
      assert_equal spec.fetch(:info), widget.info
      assert_equal expected_path(spec), widget.link_to.call(admin_context)
      assert_equal spec.fetch(:link_label), widget.link_label
      assert_equal :site, widget.blast_radius
    end
  end

  def test_count_widgets_do_not_read_metrics_timeseries
    charts = File.read(File.expand_path("../lib/recording_studio_oauth/admin/metric_chart_widgets.rb", __dir__))

    refute_includes charts, "RecordingStudioMetrics::Admin.chart_series"
    refute_includes charts, "start_at"
    refute_includes charts, "365.days"
    assert_includes charts, "OauthClient.active.where(self_registered: true)"
    assert_includes charts, "OauthAuthorization.active.count"
    assert_includes charts, "OauthAuthorization.where.not(revoked_at: nil)"
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
