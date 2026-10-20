# frozen_string_literal: true

require "test_helper"

class AdminOauthClientsFiltersTest < Minitest::Test
  def test_registered_apps_screen_filters_source_status_and_host_apis
    filters = RecordingStudioOauth::Admin::OauthClientsScreen.filters
    keys = filters.map(&:key)

    assert_equal %i[source status api], keys
    assert_equal :inline, RecordingStudioOauth::Admin::OauthClientsScreen.filter_presentation

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

  def test_new_app_button_is_secondary
    button = RecordingStudioOauth::Admin::OauthClientsScreen.buttons_value.find { |item| item.name == :new }

    assert_equal "New app", button.text
    assert_equal :secondary, button.style
  end

  def test_connections_screen_defaults_status_to_active
    filters = RecordingStudioOauth::Admin::OauthConnectionsScreen.filters
    status = filters.find { |filter| filter.key == :status }

    assert_equal [:status], filters.map(&:key)
    assert_equal :inline, RecordingStudioOauth::Admin::OauthConnectionsScreen.filter_presentation
    assert_equal %w[active revoked], status.allowed_values
    assert_equal :active, status.options[:default]
  end

  def test_granted_and_revoked_widgets_open_matching_connection_filters
    RecordingStudioOauth::Admin.register!
    granted = RecordingStudioAdmin.widget_for("oauth.granted_over_time")
    revoked = RecordingStudioAdmin.widget_for("oauth.revoked_over_time")
    self_registered = RecordingStudioAdmin.widget_for("oauth.self_registered_over_time")
    context = Struct.new(:current_actor, :timezone) do
      def admin_screen_path(key)
        "/admin/screens/#{key}"
      end
    end.new(Object.new, "UTC")

    granted_link = granted.link_to.call(context)
    revoked_link = revoked.link_to.call(context)
    self_registered_link = self_registered.link_to.call(context)

    assert_includes granted_link, "/admin/screens/oauth_connections"
    assert_includes granted_link, "status=active"
    refute_includes granted_link, "status=revoked"
    assert_includes revoked_link, "/admin/screens/oauth_connections"
    assert_includes revoked_link, "status=revoked"
    assert_includes self_registered_link, "/admin/screens/oauth_clients"
    assert_includes self_registered_link, "source=self_registered"
  end
end
