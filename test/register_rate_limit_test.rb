# frozen_string_literal: true

require "test_helper"
require "active_support/cache"

class RegisterRateLimitTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
    @cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioOauth::RegisterRateLimit.cache = @cache
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
    RecordingStudioOauth::RegisterRateLimit.cache = nil
  end

  def test_allows_until_the_per_minute_limit
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 2

    assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    refute RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    assert RecordingStudioOauth::RegisterRateLimit.allow?("2.2.2.2")
  end

  def test_zero_limit_disables_throttling
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 0

    3.times { assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1") }
  end
end
