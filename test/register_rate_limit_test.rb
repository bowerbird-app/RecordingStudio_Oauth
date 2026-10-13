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

  def test_storage_key_matches_legacy_register_ip_shape
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 2

    assert RecordingStudioOauth::RegisterRateLimit.allow?("9.8.7.6")

    assert_equal 1, @cache.read("recording_studio_oauth/register/9.8.7.6")
    assert_nil @cache.read("rsc:rate/recording_studio_oauth/register/9.8.7.6")
    assert_nil @cache.read("recording_studio_oauth/register:9.8.7.6")
  end

  def test_blank_ip_uses_unknown_storage_key
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 1

    assert RecordingStudioOauth::RegisterRateLimit.allow?(nil)
    assert_equal 1, @cache.read("recording_studio_oauth/register/unknown")
    refute RecordingStudioOauth::RegisterRateLimit.allow?("")
  end

  def test_injected_cache_is_the_store_used_for_counts
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 1
    other = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioOauth::RegisterRateLimit.cache = other

    assert RecordingStudioOauth::RegisterRateLimit.allow?("5.5.5.5")
    assert_equal 1, other.read("recording_studio_oauth/register/5.5.5.5")
    assert_nil @cache.read("recording_studio_oauth/register/5.5.5.5")
  end
end
