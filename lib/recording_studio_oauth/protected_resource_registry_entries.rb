# frozen_string_literal: true

module RecordingStudioOauth
  module ProtectedResourceRegistryEntries
    DEFAULT_API_MOUNT_PATH = "/recording_studio_api"
    DEFAULT_MCP_MOUNT_PATH = "/recording_studio_mcp"

    module_function

    def public_entries(configuration)
      seen = {}
      entries = []
      add_entry!(entries, seen, api_entry(configuration, "public"))
      add_entry!(entries, seen, mcp_entry(configuration, "public"))
      add_entry!(entries, seen, origin_entry) if configuration.register_origin_as_protected_resource
      extra_paths(configuration).each do |path|
        add_entry!(entries, seen, ProtectedResource.new(kind: :extra, path: path))
      end
      entries
    end

    def named_entries(configuration, api_key)
      seen = {}
      entries = []
      add_entry!(entries, seen, api_entry(configuration, api_key))
      add_entry!(entries, seen, mcp_entry(configuration, api_key))
      entries
    end

    def api_entry(configuration, api_key)
      mount = normalize_path(configuration.api_mount_path.presence || DEFAULT_API_MOUNT_PATH)
      path = api_key == "public" ? "#{mount}/api" : "#{mount}/apis/#{api_key}"
      ProtectedResource.new(kind: :api, path: path)
    end

    def mcp_entry(configuration, api_key)
      mount = normalize_path(configuration.mcp_mount_path.presence || DEFAULT_MCP_MOUNT_PATH)
      path = api_key == "public" ? mount : "#{mount}/apis/#{api_key}"
      ProtectedResource.new(kind: :mcp, path: path)
    end

    def origin_entry
      ProtectedResource.new(kind: :origin, path: "")
    end

    def extra_paths(configuration)
      Array(configuration.extra_protected_resource_paths).map { |path| normalize_path(path) }.uniq
    end

    def add_entry!(entries, seen, entry)
      raise ArgumentError, "protected resource path #{entry.path.inspect} is already registered" if seen.key?(entry.path)

      seen[entry.path] = true
      entries << entry
    end

    def normalize_path(value)
      cleaned = value.to_s.strip
      return "" if cleaned.empty? || cleaned == "/"

      cleaned = "/#{cleaned}" unless cleaned.start_with?("/")
      cleaned.sub(%r{/+\z}, "")
    end
  end
end
