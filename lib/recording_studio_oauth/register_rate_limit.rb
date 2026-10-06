# frozen_string_literal: true

module RecordingStudioOauth
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
      limit = RecordingStudioOauth.configuration.self_registered_apps_per_minute
      return true if limit.to_i <= 0

      next_count <= limit.to_i
    end

    private

    def next_count
      key = "#{CACHE_PREFIX}/#{@ip}"
      expires_in = 1.minute
      count = self.class.cache.increment(key, 1, expires_in: expires_in)
      return count if count.present?

      written = self.class.cache.write(key, 1, expires_in: expires_in, unless_exist: true)
      return 1 if written

      (self.class.cache.read(key) || 1).to_i
    end
  end
end
