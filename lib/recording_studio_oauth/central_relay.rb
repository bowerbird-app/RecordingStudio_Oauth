# frozen_string_literal: true

module RecordingStudioOauth
  module CentralRelay
    CONNECT_PATH = "/connect"
    CALLBACK_PATH = "/callback"

    module_function

    def connect_path
      "#{mount_path}#{CONNECT_PATH}"
    end

    def callback_path
      "#{mount_path}#{CALLBACK_PATH}"
    end

    def connect_url(base_url:)
      "#{normalize_base(base_url)}#{connect_path}"
    end

    def callback_url(base_url:)
      "#{normalize_base(base_url)}#{callback_path}"
    end

    def mount_path
      path = RecordingStudioOauth.configuration.engine_mount_path.to_s
      path.start_with?("/") ? path.chomp("/") : "/#{path}".chomp("/")
    end

    def normalize_base(base_url)
      base_url.to_s.chomp("/")
    end
  end
end
