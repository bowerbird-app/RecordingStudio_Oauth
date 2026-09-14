# frozen_string_literal: true

require "uri"

module RecordingStudioOauth
  class ProtectedResourceRegistry
    DEFAULT_API_MOUNT_PATH = "/recording_studio_api"
    DEFAULT_MCP_MOUNT_PATH = "/recording_studio_mcp"
    DEFAULT_MCP_REALM = "RecordingStudioMcp"

    attr_reader :api_key, :entries

    def initialize(api_key:, entries:, public_origin: nil)
      @api_key = api_key.to_s
      @entries = Array(entries).freeze
      @public_origin = public_origin.to_s.strip.presence
      freeze
    end

    def self.build(configuration:, api_key: "public")
      key = api_key.to_s.presence || "public"
      entries = key == "public" ? public_entries(configuration) : [api_entry(configuration, key)]
      new(api_key: key, entries: entries, public_origin: configuration.public_origin)
    end

    def self.draw_origin_well_known(mapper)
      mapper.get "/.well-known/oauth-protected-resource",
                 to: "recording_studio_oauth/oauth_discoveries#protected_resource",
                 defaults: { api_key: "public" }
      mapper.get "/.well-known/oauth-protected-resource/*resource_path",
                 to: "recording_studio_oauth/oauth_discoveries#protected_resource",
                 defaults: { api_key: "public" }
    end

    def resolve(path_suffix:)
      suffix = path_suffix.to_s.delete_prefix("/")
      return find(kind: :origin) if suffix.empty?

      entries.find { |entry| entry.path_suffix == suffix }
    end

    def find(kind:)
      wanted = kind.to_sym
      entries.find { |entry| entry.kind == wanted }
    end

    def permit?(resource, base_url: nil)
      return false if resource.is_a?(Array)
      return true if resource.nil? || resource.to_s.strip.empty?

      uri = parse_absolute_http_uri(resource)
      return false unless uri

      entry = resolve(path_suffix: uri_path_suffix(uri))
      return false unless entry

      expected_base = base_url.to_s.strip.presence || @public_origin
      return true if expected_base.blank?

      entry.identifier_for(base_url: expected_base) == identifier_from_uri(uri)
    end

    def identifiers(base_url:)
      entries.map { |entry| entry.identifier_for(base_url: base_url) }
    end

    def www_authenticate_challenge(base_url:, realm: DEFAULT_MCP_REALM)
      find(kind: :mcp)&.www_authenticate(base_url: base_url, realm: realm)
    end

    class << self
      private

      def public_entries(configuration)
        seen = {}
        entries = []
        add_entry!(entries, seen, api_entry(configuration, "public"))
        add_entry!(entries, seen, mcp_entry(configuration))
        add_entry!(entries, seen, origin_entry) if configuration.register_origin_as_protected_resource
        extra_paths(configuration).each do |path|
          add_entry!(entries, seen, ProtectedResource.new(kind: :extra, path: path))
        end
        entries
      end

      def api_entry(configuration, api_key)
        mount = normalize_path(configuration.api_mount_path.presence || DEFAULT_API_MOUNT_PATH)
        path = api_key == "public" ? "#{mount}/api" : "#{mount}/apis/#{api_key}"
        ProtectedResource.new(kind: :api, path: path)
      end

      def mcp_entry(configuration)
        ProtectedResource.new(
          kind: :mcp,
          path: normalize_path(configuration.mcp_mount_path.presence || DEFAULT_MCP_MOUNT_PATH)
        )
      end

      def origin_entry
        ProtectedResource.new(kind: :origin, path: "")
      end

      def extra_paths(configuration)
        Array(configuration.extra_protected_resource_paths).map { |path| normalize_path(path) }.uniq
      end

      def add_entry!(entries, seen, entry)
        if seen.key?(entry.path)
          raise ArgumentError, "protected resource path #{entry.path.inspect} is already registered"
        end

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

    private

    def parse_absolute_http_uri(value)
      uri = URI.parse(value.to_s.strip)
      return unless uri.is_a?(URI::HTTP)
      return if uri.host.to_s.empty?
      return if uri.userinfo.present?
      return if uri.query.present?
      return if uri.fragment.present?

      uri
    rescue URI::InvalidURIError
      nil
    end

    def uri_path_suffix(uri)
      path = uri.path.to_s.sub(%r{/+\z}, "")
      return "" if path.empty? || path == "/"

      path.delete_prefix("/")
    end

    def identifier_from_uri(uri)
      origin = "#{uri.scheme}://#{uri.host}"
      origin = "#{origin}:#{uri.port}" unless default_port?(uri)
      path = uri.path.to_s.sub(%r{/+\z}, "")
      path.empty? || path == "/" ? origin : "#{origin}#{path}"
    end

    def default_port?(uri)
      (uri.scheme == "http" && uri.port == 80) || (uri.scheme == "https" && uri.port == 443)
    end
  end
end
