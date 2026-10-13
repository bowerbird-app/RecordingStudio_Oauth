# frozen_string_literal: true

require "recording_studio_cache"

module RecordingStudioOauth
  # Thin adapter over {RecordingStudioCache::RateLimiter} for `/register`.
  #
  # Keeps the legacy storage key shape
  # +recording_studio_oauth/register/<IP>+ (or +unknown+ when the IP is blank),
  # the +self_registered_apps_per_minute+ config, a one-minute TTL window, and
  # main's store resolution via {.cache} (+@cache || Rails.cache+ — there is no
  # +Configuration#cache_store+).
  #
  # Main's +limit.to_i <= 0+ short-circuit runs before the shared limiter is
  # constructed, so a disabled limit never hits cache or period validation.
  # Store errors still raise (see +NeverRescued+).
  class RegisterRateLimit
    CACHE_PREFIX = "recording_studio_oauth/register"
    # Main always used +expires_in: 1.minute+; period is not configurable.
    WINDOW = 1.minute
    # v0.5.0 rejects rescue_errors: []. Main propagated all store errors; this
    # sentinel is never raised, so the shared limiter rescues nothing.
    NeverRescued = Class.new(StandardError)

    class << self
      attr_writer :cache

      # Same store main used in +next_count+: injectable override, else +Rails.cache+.
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
      limit = RecordingStudioOauth.configuration.self_registered_apps_per_minute
      return true if limit.to_i <= 0

      RecordingStudioCache::RateLimiter.new(**limiter_options(limit)).allow?
    end

    private

    def storage_key
      "#{CACHE_PREFIX}/#{@ip}"
    end

    def limiter_options(limit)
      {
        storage_key: storage_key,
        limit: limit.to_i,
        period: WINDOW,
        backend: :rails_cache,
        strategy: :ttl,
        store: self.class.cache,
        rescue_errors: [NeverRescued]
      }
    end
  end
end
