# frozen_string_literal: true

require "test_helper"

class ProtectedResourceDiscoveryTest < ActionDispatch::IntegrationTest
  HOST = "http://www.example.com"

  teardown do
    RecordingStudioOauth.configuration.register_origin_as_protected_resource = false
    RecordingStudioOauth.configuration.engine_mount_path = "/recording_studio_oauth"
  end

  test "engine unsuffixed PRM is the API identifier" do
    get "/recording_studio_oauth/.well-known/oauth-protected-resource"

    assert_response :success
    assert_equal(
      {
        "resource" => "#{HOST}/recording_studio_api/api",
        "authorization_servers" => ["#{HOST}/recording_studio_oauth"],
        "bearer_methods_supported" => ["header"]
      },
      JSON.parse(response.body)
    )
  end

  test "origin path-inserted MCP PRM is the MCP identifier" do
    get "/.well-known/oauth-protected-resource/recording_studio_mcp"

    assert_response :success
    assert_equal(
      {
        "resource" => "#{HOST}/recording_studio_mcp",
        "authorization_servers" => ["#{HOST}/recording_studio_oauth"],
        "bearer_methods_supported" => ["header"]
      },
      JSON.parse(response.body)
    )
  end

  test "origin unsuffixed PRM is 404 unless origin is registered" do
    get "/.well-known/oauth-protected-resource"

    assert_response :not_found

    RecordingStudioOauth.configuration.register_origin_as_protected_resource = true
    get "/.well-known/oauth-protected-resource"

    assert_response :success
    assert_equal "#{HOST}", JSON.parse(response.body).fetch("resource")
    refute_equal "#{HOST}/recording_studio_api/api", JSON.parse(response.body).fetch("resource")
  end

  test "origin path-inserted API twin is the API identifier" do
    get "/.well-known/oauth-protected-resource/recording_studio_api/api"

    assert_response :success
    assert_equal "#{HOST}/recording_studio_api/api", JSON.parse(response.body).fetch("resource")
  end

  test "unknown origin path suffix is 404" do
    get "/.well-known/oauth-protected-resource/not-a-resource"

    assert_response :not_found
  end

  test "named API engine PRM stays that API identifier" do
    get "/recording_studio_oauth/apis/operations/.well-known/oauth-protected-resource"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "#{HOST}/recording_studio_api/apis/operations", body.fetch("resource")
    assert_equal ["#{HOST}/recording_studio_oauth/apis/operations"], body.fetch("authorization_servers")
  end

  test "origin PRM issuer uses engine_mount_path" do
    RecordingStudioOauth.configuration.engine_mount_path = "/oauth"

    get "/.well-known/oauth-protected-resource/recording_studio_mcp"

    assert_response :success
    assert_equal ["#{HOST}/oauth"], JSON.parse(response.body).fetch("authorization_servers")
  end
end
