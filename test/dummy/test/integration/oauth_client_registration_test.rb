# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "active_support/cache"

class OauthClientRegistrationTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_allow = RecordingStudioOauth.configuration.allow_self_registered_apps?
    @previous_limit = RecordingStudioOauth.configuration.self_registered_apps_per_minute
    RecordingStudioOauth.configuration.allow_self_registered_apps = true
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 10
  end

  teardown do
    RecordingStudioOauth.configuration.allow_self_registered_apps = @previous_allow
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = @previous_limit
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
  end

  test "registers a public client with PKCE required" do
    post "/recording_studio_oauth/register",
         params: {
           client_name: "MCP Inspector",
           redirect_uris: ["http://127.0.0.1:6274/callback"],
           token_endpoint_auth_method: "none",
           grant_types: %w[authorization_code refresh_token],
           response_types: ["code"]
         },
         as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_match(/\Arsoauth_oc_/, body.fetch("client_id"))
    assert_kind_of Integer, body.fetch("client_id_issued_at")
    assert_equal "MCP Inspector", body.fetch("client_name")
    assert_equal ["http://127.0.0.1:6274/callback"], body.fetch("redirect_uris")
    assert_equal "none", body.fetch("token_endpoint_auth_method")
    refute body.key?("client_secret")

    client = RecordingStudioOauth::OauthClient.find_by!(client_id: body.fetch("client_id"))
    assert client.self_registered?
    refute client.confidential?
    refute client.allow_registration?

    user = create_user
    _root, access_recording = create_access_recording_for(user: user)
    sign_in user

    get authorize_path, params: {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: "http://127.0.0.1:6274/callback",
      state: "xyz"
    }

    assert_response :redirect
    location = URI.parse(response.location)
    error = CGI.parse(location.query.to_s).fetch("error").first
    assert_equal "invalid_request", error
  end

  test "returns a secret once for confidential registration" do
    post "/recording_studio_oauth/register",
         params: {
           client_name: "Server App",
           redirect_uris: ["https://app.example.com/callback"],
           token_endpoint_auth_method: "client_secret_post"
         },
         as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_match(/\Arsoauth_cs_/, body.fetch("client_secret"))
    assert_equal 0, body.fetch("client_secret_expires_at")
    client = RecordingStudioOauth::OauthClient.find_by!(client_id: body.fetch("client_id"))
    assert client.confidential?
    assert client.authenticate_secret?(body.fetch("client_secret"))
  end

  test "rejects invalid redirect URIs with RFC 7591 errors" do
    post "/recording_studio_oauth/register",
         params: { redirect_uris: ["http://example.com/callback"] },
         as: :json

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal "invalid_redirect_uri", body.fetch("error")
  end

  test "rejects unknown token auth methods" do
    post "/recording_studio_oauth/register",
         params: {
           redirect_uris: ["https://app.example.com/callback"],
           token_endpoint_auth_method: "private_key_jwt"
         },
         as: :json

    assert_response :bad_request
    assert_equal "invalid_client_metadata", JSON.parse(response.body).fetch("error")
  end

  test "policy off rejects registration" do
    RecordingStudioOauth.configuration.allow_self_registered_apps = false

    assert_no_difference -> { RecordingStudioOauth::OauthClient.where(self_registered: true).count } do
      post "/recording_studio_oauth/register",
           params: { redirect_uris: ["https://app.example.com/callback"] },
           as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client_metadata", JSON.parse(response.body).fetch("error")
  end

  test "registers a client bound to a named API" do
    post "/recording_studio_oauth/apis/operations/register",
         params: {
           client_name: "ChatGPT",
           redirect_uris: ["https://chatgpt.com/connector_platform_oauth_redirect"],
           token_endpoint_auth_method: "none"
         },
         as: :json

    assert_response :created
    client = RecordingStudioOauth::OauthClient.find_by!(client_id: JSON.parse(response.body).fetch("client_id"))
    assert_equal "operations", client.api_key
    assert client.self_registered?
  end

  test "named API register returns invalid_client_metadata when self-registration is off" do
    RecordingStudioOauth.configuration.allow_self_registered_apps = false

    assert_no_difference -> { RecordingStudioOauth::OauthClient.count } do
      post "/recording_studio_oauth/apis/operations/register",
           params: { redirect_uris: ["https://app.example.com/callback"] },
           as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_client_metadata", JSON.parse(response.body).fetch("error")
  end

  test "named API register rejects an unknown api key" do
    assert_no_difference -> { RecordingStudioOauth::OauthClient.count } do
      post "/recording_studio_oauth/apis/nope/register",
           params: { redirect_uris: ["https://app.example.com/callback"] },
           as: :json
    end

    assert_response :not_found
    assert_equal "invalid_request", JSON.parse(response.body).fetch("error")
  end

  test "named API metadata registration_endpoint is a working route" do
    get "/.well-known/oauth-authorization-server/recording_studio_oauth/apis/operations"
    assert_response :success
    endpoint = JSON.parse(response.body).fetch("registration_endpoint")
    assert_equal "http://www.example.com/recording_studio_oauth/apis/operations/register", endpoint

    post URI.parse(endpoint).path,
         params: { redirect_uris: ["https://app.example.com/callback"] },
         as: :json

    assert_response :created
    client = RecordingStudioOauth::OauthClient.find_by!(client_id: JSON.parse(response.body).fetch("client_id"))
    assert_equal "operations", client.api_key
  end

  test "rate limits register per IP" do
    RecordingStudioOauth::RegisterRateLimit.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioOauth.configuration.self_registered_apps_per_minute = 1

    post "/recording_studio_oauth/register",
         params: { redirect_uris: ["https://app.example.com/one"] },
         as: :json
    assert_response :created

    post "/recording_studio_oauth/register",
         params: { redirect_uris: ["https://app.example.com/two"] },
         as: :json
    assert_response :too_many_requests
    assert_equal "temporarily_unavailable", JSON.parse(response.body).fetch("error")
  ensure
    RecordingStudioOauth::RegisterRateLimit.cache = nil
  end
end
