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

  def test_zero_limit_disables_throttling_without_cache_writes
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 0

    3.times { assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1") }
    assert_nil @cache.read("recording_studio_oauth/register/1.1.1.1")
  end

  def test_nil_limit_disables_throttling_like_main_to_i
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = nil

    assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    assert_nil @cache.read("recording_studio_oauth/register/1.1.1.1")
  end

  def test_blank_limit_disables_throttling_like_main_to_i
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = ""

    assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    assert_nil @cache.read("recording_studio_oauth/register/1.1.1.1")
  end

  def test_negative_limit_disables_throttling_like_main_to_i
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = -3

    assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    assert_nil @cache.read("recording_studio_oauth/register/1.1.1.1")
  end

  def test_string_limit_coerces_with_to_i_like_main
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = "2"

    assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    assert RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    refute RecordingStudioOauth::RegisterRateLimit.allow?("1.1.1.1")
    assert_equal 3, @cache.read("recording_studio_oauth/register/1.1.1.1")
  end

  def test_window_is_hardcoded_one_minute_like_main
    # Main used expires_in: 1.minute only; period is not a config key.
    # Shared RateLimiter coerces via period.to_i (Duration and "60" both → 60).
    assert_equal 1.minute, RecordingStudioOauth::RegisterRateLimit::WINDOW
    assert_equal 60, RecordingStudioOauth::RegisterRateLimit::WINDOW.to_i
    assert_equal 60, "60".to_i
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

  def test_store_is_register_rate_limit_cache_not_configuration
    # Main had no Configuration#cache / #cache_store; only RegisterRateLimit.cache.
    refute RecordingStudioOauth.configuration.respond_to?(:cache)
    refute RecordingStudioOauth.configuration.respond_to?(:cache_store)

    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 1
    injected = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioOauth::RegisterRateLimit.cache = injected

    assert_same injected, RecordingStudioOauth::RegisterRateLimit.cache
    assert RecordingStudioOauth::RegisterRateLimit.allow?("8.8.8.8")
    assert_equal 1, injected.read("recording_studio_oauth/register/8.8.8.8")
  end

  def test_cache_defaults_to_rails_cache_when_not_injected
    RecordingStudioOauth::RegisterRateLimit.cache = nil
    rails_store = ActiveSupport::Cache::MemoryStore.new

    Rails.stub(:cache, rails_store) do
      assert_same rails_store, RecordingStudioOauth::RegisterRateLimit.cache

      RecordingStudioOauth.configuration.self_registered_apps_per_minute = 1
      assert RecordingStudioOauth::RegisterRateLimit.allow?("7.7.7.7")
      assert_equal 1, rails_store.read("recording_studio_oauth/register/7.7.7.7")
      assert_nil @cache.read("recording_studio_oauth/register/7.7.7.7")
    end
  end
end
