# frozen_string_literal: true

require "test_helper"

class ProtectedResourceRegistryTest < Minitest::Test
  BASE_URL = "https://app.example.com"
  ISSUER = "https://app.example.com/recording_studio_oauth"

  def setup
    @original_configuration = RecordingStudioOauth.instance_variable_get(:@configuration)
    RecordingStudioOauth.instance_variable_set(:@configuration, RecordingStudioOauth::Configuration.new)
    @configuration = RecordingStudioOauth.configuration
  end

  def teardown
    RecordingStudioOauth.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_public_defaults_include_api_and_mcp_but_not_origin
    registry = build_registry

    assert_equal %i[api mcp], registry.entries.map(&:kind)
    assert_equal [
      "https://app.example.com/recording_studio_api/api",
      "https://app.example.com/recording_studio_mcp"
    ], registry.identifiers(base_url: BASE_URL)
    assert_nil registry.find(kind: :origin)
  end

  def test_named_api_registry_excludes_mcp
    registry = build_registry(api_key: "operations")

    assert_equal [:api], registry.entries.map(&:kind)
    assert_equal ["https://app.example.com/recording_studio_api/apis/operations"], registry.identifiers(base_url: BASE_URL)
    assert_nil registry.find(kind: :mcp)
    assert_nil registry.resolve(path_suffix: "recording_studio_mcp")
  end

  def test_resolve_matches_path_suffixes
    registry = build_registry

    api = registry.resolve(path_suffix: "recording_studio_api/api")
    mcp = registry.resolve(path_suffix: "recording_studio_mcp")

    assert_equal :api, api.kind
    assert_equal "/recording_studio_api/api", api.path
    assert_equal :mcp, mcp.kind
    assert_equal "/recording_studio_mcp", mcp.path
    assert_nil registry.resolve(path_suffix: "unknown")
  end

  def test_empty_suffix_resolves_origin_only
    default_registry = build_registry
    @configuration.register_origin_as_protected_resource = true
    origin_registry = build_registry

    assert_nil default_registry.resolve(path_suffix: "")
    assert_equal :origin, origin_registry.resolve(path_suffix: "").kind
    assert_equal "https://app.example.com", origin_registry.resolve(path_suffix: "").identifier_for(base_url: BASE_URL)
    refute_equal :api, origin_registry.resolve(path_suffix: "").kind
  end

  def test_permit_accepts_blank_omitted_and_registered_uris
    registry = build_registry

    assert registry.permit?(nil, base_url: BASE_URL)
    assert registry.permit?("", base_url: BASE_URL)
    assert registry.permit?("   ", base_url: BASE_URL)
    assert registry.permit?("https://app.example.com/recording_studio_api/api", base_url: BASE_URL)
    assert registry.permit?("https://app.example.com/recording_studio_mcp", base_url: BASE_URL)
  end

  def test_permit_rejects_unknown_array_and_mismatched_host
    registry = build_registry

    refute registry.permit?("https://app.example.com/unknown", base_url: BASE_URL)
    refute registry.permit?(["https://app.example.com/recording_studio_mcp"], base_url: BASE_URL)
    refute registry.permit?("https://other.example.com/recording_studio_mcp", base_url: BASE_URL)
    refute registry.permit?("https://app.example.com/recording_studio_mcp?x=1", base_url: BASE_URL)
    refute registry.permit?("/recording_studio_mcp", base_url: BASE_URL)
    refute registry.permit?("not a uri", base_url: BASE_URL)
  end

  def test_permit_without_base_url_accepts_any_host_for_a_registered_path
    registry = build_registry

    assert registry.permit?("https://other.example.com/recording_studio_mcp")
    refute registry.permit?("https://other.example.com/unknown")
  end

  def test_permit_without_base_url_uses_public_origin_when_set
    @configuration.public_origin = BASE_URL
    registry = build_registry

    assert registry.permit?("https://app.example.com/recording_studio_mcp")
    refute registry.permit?("https://other.example.com/recording_studio_mcp")
  end

  def test_custom_mounts_origin_and_extras
    @configuration.api_mount_path = "/api"
    @configuration.mcp_mount_path = "/mcp"
    @configuration.register_origin_as_protected_resource = true
    @configuration.extra_protected_resource_paths = ["/hooks", "hooks"]
    registry = build_registry

    assert_equal [
      "https://app.example.com/api/api",
      "https://app.example.com/mcp",
      "https://app.example.com",
      "https://app.example.com/hooks"
    ], registry.identifiers(base_url: BASE_URL)
    assert_equal :extra, registry.resolve(path_suffix: "hooks").kind
  end

  def test_overlapping_extra_path_raises
    @configuration.extra_protected_resource_paths = ["/recording_studio_mcp"]

    error = assert_raises(ArgumentError) { build_registry }
    assert_equal "protected resource path \"/recording_studio_mcp\" is already registered", error.message
  end

  def test_per_suffix_metadata_json
    registry = build_registry
    api = registry.resolve(path_suffix: "recording_studio_api/api")
    mcp = registry.resolve(path_suffix: "recording_studio_mcp")

    assert_equal(
      {
        resource: "https://app.example.com/recording_studio_api/api",
        authorization_servers: [ISSUER],
        bearer_methods_supported: ["header"]
      },
      api.metadata(base_url: BASE_URL, issuer: ISSUER)
    )
    assert_equal(
      {
        resource: "https://app.example.com/recording_studio_mcp",
        authorization_servers: [ISSUER],
        bearer_methods_supported: ["header"]
      },
      mcp.metadata(base_url: BASE_URL, issuer: ISSUER)
    )
  end

  def test_www_authenticate_challenge_points_at_mcp_metadata
    registry = build_registry

    assert_equal(
      'Bearer realm="RecordingStudioMcp", resource_metadata="https://app.example.com/.well-known/oauth-protected-resource/recording_studio_mcp"',
      registry.www_authenticate_challenge(base_url: BASE_URL)
    )
    assert_equal(
      "https://app.example.com/.well-known/oauth-protected-resource/recording_studio_mcp",
      registry.find(kind: :mcp).metadata_url(base_url: BASE_URL)
    )
  end

  def test_facade_builds_from_module_configuration
    registry = RecordingStudioOauth.protected_resources

    assert_equal "public", registry.api_key
    assert_equal %i[api mcp], registry.entries.map(&:kind)
  end

  def test_draw_origin_well_known_draws_origin_root_routes
    drawn = []
    mapper = Object.new
    mapper.define_singleton_method(:get) { |path, **options| drawn << [path, options] }

    RecordingStudioOauth::ProtectedResourceRegistry.draw_origin_well_known(mapper)

    assert_equal [
      [
        "/.well-known/oauth-protected-resource",
        {
          to: "recording_studio_oauth/oauth_discoveries#protected_resource",
          defaults: { api_key: "public" }
        }
      ],
      [
        "/.well-known/oauth-protected-resource/*resource_path",
        {
          to: "recording_studio_oauth/oauth_discoveries#protected_resource",
          defaults: { api_key: "public" }
        }
      ]
    ], drawn
  end

  def test_origin_entry_rejects_a_path
    error = assert_raises(ArgumentError) do
      RecordingStudioOauth::ProtectedResource.new(kind: :origin, path: "/nope")
    end

    assert_equal "origin protected resource path must be empty", error.message
  end

  private

  def build_registry(api_key: "public")
    RecordingStudioOauth::ProtectedResourceRegistry.build(configuration: @configuration, api_key: api_key)
  end
end
