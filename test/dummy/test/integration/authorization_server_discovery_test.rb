# frozen_string_literal: true

require "test_helper"

class AuthorizationServerDiscoveryTest < ActionDispatch::IntegrationTest
  HOST = "http://www.example.com"
  ISSUER = "#{HOST}/recording_studio_oauth".freeze

  teardown do
    RecordingStudioOauth.configuration.allow_self_registered_apps = true
    RecordingStudioOauth.configuration.engine_mount_path = "/recording_studio_oauth"
  end

  test "RFC 8414 path insertion issuer equals the mount URL" do
    get "/.well-known/oauth-authorization-server/recording_studio_oauth"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal ISSUER, body.fetch("issuer")
    assert_equal "#{ISSUER}/oauth/authorize", body.fetch("authorization_endpoint")
    assert_includes body.fetch("token_endpoint"), "/recording_studio_api/oauth/token"
    assert_equal "#{ISSUER}/register", body.fetch("registration_endpoint")
  end

  test "engine and origin unsuffixed metadata keep the same issuer" do
    get "/recording_studio_oauth/.well-known/oauth-authorization-server"
    engine_body = JSON.parse(response.body)

    get "/.well-known/oauth-authorization-server"
    origin_body = JSON.parse(response.body)

    assert_response :success
    assert_equal ISSUER, engine_body.fetch("issuer")
    assert_equal ISSUER, origin_body.fetch("issuer")
  end

  test "unknown path-inserted issuer is 404" do
    get "/.well-known/oauth-authorization-server/not_this_host"

    assert_response :not_found
  end

  test "openid configuration stays 404" do
    get "/.well-known/openid-configuration/recording_studio_oauth"
    assert_response :not_found

    get "/recording_studio_oauth/.well-known/openid-configuration"
    assert_response :not_found
  end

  test "registration_endpoint is omitted when self-registered apps are off" do
    RecordingStudioOauth.configuration.allow_self_registered_apps = false

    get "/.well-known/oauth-authorization-server/recording_studio_oauth"

    assert_response :success
    refute JSON.parse(response.body).key?("registration_endpoint")
  end

  test "named API path insertion matches the named issuer" do
    get "/.well-known/oauth-authorization-server/recording_studio_oauth/apis/operations"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "#{ISSUER}/apis/operations", body.fetch("issuer")
    assert_includes body.fetch("token_endpoint"), "/recording_studio_api/apis/operations/oauth/token"
  end
end
