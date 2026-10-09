# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  def test_metrics_register_with_operations_expose_and_staff_view
    metrics = File.read(File.expand_path("../lib/recording_studio_oauth/metrics.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_oauth/engine.rb", __dir__))
    gemspec = File.read(File.expand_path("../recording_studio_oauth.gemspec", __dir__))
    dummy_metrics = File.read(File.expand_path("dummy/config/initializers/recording_studio_metrics.rb", __dir__))

    assert_includes metrics, "RecordingStudioMetrics.register"
    assert_includes metrics, ":oauth_clients"
    assert_includes metrics, "RecordingStudioOauth::OauthClient"
    assert_includes metrics, "count :total"
    assert_includes metrics, "OauthClient.active"
    assert_includes metrics, "OauthAuthorization.active"
    assert_includes metrics, "breakdown :by_registration"
    assert_includes metrics, "field: :self_registered"
    assert_includes metrics, ":oauth_authorizations"
    assert_includes metrics, "RecordingStudioOauth::OauthAuthorization"
    assert_includes metrics, "timeseries :over_time"
    assert_includes metrics, "field: :created_at"
    assert_includes metrics, "breakdown :by_role"
    assert_includes metrics, "field: :role"
    assert_includes metrics, "blast_radius: :site"
    assert_includes metrics, "expose: EXPOSE"
    assert_includes metrics, "api: [API]"
    assert_includes metrics, "API = :operations"
    assert_includes metrics, "Api::Access.can_view?"
    refute_includes metrics, "confirmable_column?"
    refute_includes metrics, "RecordingStudioMetrics::Api.register!"
    refute_includes metrics, "respond_to?"
    refute_includes metrics, "rescue"

    assert_includes engine, 'initializer "recording_studio_oauth.metrics"'
    assert_includes engine, "RecordingStudioOauth::Metrics.register!"
    refute_includes engine, "RecordingStudioMetrics::Api.register!"

    assert_includes gemspec, 'spec.add_dependency "recording_studio_metrics", "~> 0.2"'
    assert_includes dummy_metrics, "RecordingStudioMetrics::Api.register!(api: :operations)"
  end
end
