# frozen_string_literal: true

require "test_helper"

class ProtectedResourcesTest < Minitest::Test
  Request = Struct.new(:base_url)

  def setup
    RecordingStudioOauth::ProtectedResources.clear!
  end

  def teardown
    RecordingStudioOauth::ProtectedResources.clear!
  end

  def test_blank_resource_is_allowed_for_looser_clients
    request = Request.new("https://studio.example")

    assert RecordingStudioOauth::ProtectedResources.allowed?(nil, request: request)
    assert RecordingStudioOauth::ProtectedResources.allowed?("", request: request)
  end

  def test_api_resource_and_origin_are_allowed_by_default
    request = Request.new("https://studio.example")

    assert RecordingStudioOauth::ProtectedResources.allowed?(
      "https://studio.example/recording_studio_api/api",
      request: request
    )
    assert RecordingStudioOauth::ProtectedResources.allowed?(
      "https://studio.example",
      request: request
    )
    refute RecordingStudioOauth::ProtectedResources.allowed?(
      "https://studio.example/recording_studio_mcp",
      request: request
    )
  end

  def test_register_protected_resource_allows_mcp_identity
    request = Request.new("https://studio.example")
    RecordingStudioOauth.register_protected_resource(
      ->(req) { "#{req.base_url}/recording_studio_mcp" }
    )

    assert RecordingStudioOauth::ProtectedResources.allowed?(
      "https://studio.example/recording_studio_mcp",
      request: request
    )
  end
end
