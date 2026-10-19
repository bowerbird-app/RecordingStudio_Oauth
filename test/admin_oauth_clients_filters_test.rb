# frozen_string_literal: true

require "test_helper"

class AdminOauthClientsFiltersTest < Minitest::Test
  def test_registered_apps_screen_filters_source_status_and_host_apis
    filters = RecordingStudioOauth::Admin::OauthClientsScreen.filters
    keys = filters.map(&:key)

    assert_equal %i[source status api], keys

    source = filters.find { |filter| filter.key == :source }
    status = filters.find { |filter| filter.key == :status }
    api = filters.find { |filter| filter.key == :api }

    assert_equal %w[staff self_registered], source.allowed_values
    assert_equal %w[active revoked], status.allowed_values
    assert_equal :active, status.options[:default]
    assert_equal :api_key, api.param_key
    assert_equal RecordingStudioOauth::Integration.api_names.map(&:to_s), api.allowed_values
    assert_includes api.allowed_values, "public"
    refute_includes api.allowed_values, "featured_in"
  end

  def test_granted_and_revoked_widgets_open_matching_client_filters
    RecordingStudioOauth::Admin.register!
    granted = RecordingStudioAdmin.widget_for("oauth.granted_over_time")
    revoked = RecordingStudioAdmin.widget_for("oauth.revoked_over_time")
    context = Struct.new(:current_actor, :timezone) do
      def admin_screen_path(key)
        "/admin/screens/#{key}"
      end
    end.new(Object.new, "UTC")

    result = RecordingStudioMetrics::Result.new(
      metric: "oauth_authorizations.granted_over_time",
      type: :timeseries,
      title: "Connections granted",
      data: []
    )

    granted_link = RecordingStudioMetrics.stub(:execute, result) { granted.resolve(context).link_to }
    revoked_link = RecordingStudioMetrics.stub(:execute, result) { revoked.resolve(context).link_to }

    assert_includes granted_link, "/admin/screens/oauth_clients"
    assert_includes granted_link, "connections=granted"
    refute_includes granted_link, "connections=revoked"
    assert_includes revoked_link, "connections=revoked"
  end
end
