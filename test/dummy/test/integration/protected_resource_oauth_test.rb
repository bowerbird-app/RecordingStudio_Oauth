# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ProtectedResourceOauthTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  HOST = "http://www.example.com"
  API_RESOURCE = "#{HOST}/recording_studio_api/api"
  MCP_RESOURCE = "#{HOST}/recording_studio_mcp"

  setup do
    @user = create_user
    @root_recording, @access_recording = create_access_recording_for(user: @user)
    @pkce = pkce_pair
    @oauth_client, = create_oauth_client
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
    RecordingStudioOauth.configuration.public_origin = nil
  end

  test "authorize rejects an unknown resource with invalid_target" do
    get authorize_path, params: authorize_params.merge(resource: "#{HOST}/unknown")

    assert_response :bad_request
    assert_includes response.body, "resource is not a registered protected resource"
  end

  test "authorize accepts MCP and API resources" do
    get authorize_path, params: authorize_params.merge(resource: MCP_RESOURCE)

    assert_response :success
    assert_includes response.body, @oauth_client.name

    get authorize_path, params: authorize_params.merge(resource: API_RESOURCE)

    assert_response :success
    assert_includes response.body, @oauth_client.name
  end

  test "authorize without resource still works" do
    get authorize_path, params: authorize_params

    assert_response :success
    assert_includes response.body, @oauth_client.name
  end

  test "token rejects an unknown resource with invalid_target" do
    approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )

    post api_token_path, params: token_params(code: approved.fetch(:code), resource: "#{HOST}/unknown")

    assert_response :bad_request
    assert_equal "invalid_target", JSON.parse(response.body).fetch("error")
    assert_equal 0, RecordingStudioOauth::OauthAccessToken.where(oauth_authorization: approved.fetch(:authorization)).count
  end

  test "token accepts MCP and API resources and omits still work" do
    mcp = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )
    post api_token_path, params: token_params(code: mcp.fetch(:code), resource: MCP_RESOURCE)

    assert_response :success
    mcp_token = JSON.parse(response.body).fetch("access_token")
    assert_match(/\Arsoauth_at_/, mcp_token)
    refute JSON.parse(response.body).key?("resource")

    get "/recording_studio_api/api/v1/workspaces",
        headers: {
          "Authorization" => "Bearer #{mcp_token}",
          "Accept" => "application/json"
        }
    assert_response :success

    api_pkce = pkce_pair
    api = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: api_pkce
    )
    post api_token_path, params: token_params(
      code: api.fetch(:code),
      resource: API_RESOURCE,
      code_verifier: api_pkce.fetch(:verifier)
    )

    assert_response :success
    assert_match(/\Arsoauth_at_/, JSON.parse(response.body).fetch("access_token"))

    omitted_pkce = pkce_pair
    omitted = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: omitted_pkce
    )
    post api_token_path, params: token_params(
      code: omitted.fetch(:code),
      code_verifier: omitted_pkce.fetch(:verifier)
    )

    assert_response :success
    assert_match(/\Arsoauth_at_/, JSON.parse(response.body).fetch("access_token"))
  end

  test "token rejects repeated resource params" do
    approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )

    post api_token_path, params: token_params(code: approved.fetch(:code)).merge(
      resource: [MCP_RESOURCE, API_RESOURCE]
    )

    assert_response :bad_request
    assert_equal "invalid_target", JSON.parse(response.body).fetch("error")
  end

  private

  def authorize_params
    {
      response_type: "code",
      client_id: @oauth_client.client_id,
      redirect_uri: "http://127.0.0.1/callback",
      state: "xyz",
      code_challenge: @pkce.fetch(:challenge),
      code_challenge_method: "S256"
    }
  end

  def token_params(code:, resource: nil, code_verifier: nil)
    {
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: code,
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: code_verifier || @pkce.fetch(:verifier),
      resource: resource
    }.compact
  end
end
