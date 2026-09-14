# frozen_string_literal: true

module RecordingStudioOauth
  class ProtectedResource
    KINDS = %i[api mcp origin extra].freeze
    WELL_KNOWN_PATH = "/.well-known/oauth-protected-resource"

    attr_reader :kind, :path

    def initialize(kind:, path:)
      @kind = kind.to_sym
      raise ArgumentError, "unknown protected resource kind #{kind.inspect}" unless KINDS.include?(@kind)

      @path = normalize_identity_path(path)
      if @kind == :origin
        raise ArgumentError, "origin protected resource path must be empty" unless @path.empty?
      elsif @path.empty?
        raise ArgumentError, "#{@kind} protected resource path cannot be empty"
      end
      freeze
    end

    def identifier_for(base_url:)
      origin = strip_trailing_slashes(base_url)
      path.empty? ? origin : "#{origin}#{path}"
    end

    def path_suffix
      path.delete_prefix("/")
    end

    def metadata_url(base_url:)
      origin = strip_trailing_slashes(base_url)
      suffix = path_suffix
      suffix.empty? ? "#{origin}#{WELL_KNOWN_PATH}" : "#{origin}#{WELL_KNOWN_PATH}/#{suffix}"
    end

    def metadata(base_url:, issuer:)
      {
        resource: identifier_for(base_url: base_url),
        authorization_servers: [issuer],
        bearer_methods_supported: ["header"]
      }
    end

    def www_authenticate(base_url:, realm:)
      %(Bearer realm="#{realm}", resource_metadata="#{metadata_url(base_url:)}")
    end

    private

    def normalize_identity_path(value)
      cleaned = value.to_s.strip
      return "" if cleaned.empty? || cleaned == "/"

      cleaned = "/#{cleaned}" unless cleaned.start_with?("/")
      strip_trailing_slashes(cleaned)
    end

    def strip_trailing_slashes(value)
      value.to_s.sub(%r{/+\z}, "")
    end
  end
end
