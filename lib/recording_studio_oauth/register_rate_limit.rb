# frozen_string_literal: true

require "recording_studio_cache"

module RecordingStudioOauth
  # Thin adapter over {RecordingStudioCache::RateLimiter} for `/register`.
  #
  # Keeps the legacy storage key shape
  # +recording_studio_oauth/register/<IP>+ (or +unknown+ when the IP is blank),
  # the +self_registered_apps_per_minute+ config, a one-minute TTL window, and
  # the injectable +.cache+ store used by tests.
  class RegisterRateLimit
    CACHE_PREFIX = "recording_studio_oauth/register"

    class << self
      attr_writer :cache

      def cache
        @cache || Rails.cache
      end

      def allow?(ip)
        new(ip).allow?
      end
    end

    def initialize(ip)
      @ip = ip.to_s.presence || "unknown"
    end

    def allow?
      RecordingStudioCache::RateLimiter.new(
        storage_key: storage_key,
        limit: RecordingStudioOauth.configuration.self_registered_apps_per_minute,
        period: 1.minute,
        backend: :rails_cache,
        strategy: :ttl,
        store: self.class.cache
      ).allow?
    end

    private

    def storage_key
      "#{CACHE_PREFIX}/#{@ip}"
    end
  end
end
