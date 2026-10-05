# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class TokenLifecycleTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    @root_recording, @access_recording = create_access_recording_for(user: @user)
    @pkce = pkce_pair
    @oauth_client, = create_oauth_client
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "re-consent keeps live tokens and does not void a later pair" do
    first = approve_and_exchange(@pkce)
    first_granted_id = first.fetch(:authorization).access_recording_id

    second_pkce = pkce_pair
    second = approve_and_exchange(second_pkce)

    assert_equal first.fetch(:authorization).id, second.fetch(:authorization).id
    assert_equal first_granted_id, second.fetch(:authorization).reload.access_recording_id
    assert_nil first.fetch(:authorization).reload.revoked_at
    refute_equal first.fetch(:issued).fetch("access_token"), second.fetch(:issued).fetch("access_token")

    assert_workspaces_with(first.fetch(:issued).fetch("access_token"))
    assert_workspaces_with(second.fetch(:issued).fetch("access_token"))

    post api_token_path, params: {
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: first.fetch(:issued).fetch("refresh_token")
    }

    assert_response :success
    rotated_first = JSON.parse(response.body)
    assert_nil first.fetch(:authorization).reload.revoked_at
    assert_workspaces_with(second.fetch(:issued).fetch("access_token"))
    assert_workspaces_with(rotated_first.fetch("access_token"))

    post api_token_path, params: {
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: second.fetch(:issued).fetch("refresh_token")
    }

    assert_response :success
    assert_nil first.fetch(:authorization).reload.revoked_at
  end

  test "replaying a rotated refresh token voids the authorization" do
    approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )
    first = exchange_authorization_code(
      client_id: @oauth_client.client_id,
      code: approved.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: @pkce.fetch(:verifier)
    )

    post api_token_path, params: {
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: first.fetch("refresh_token")
    }
    assert_response :success
    rotated = JSON.parse(response.body)

    post api_token_path, params: {
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: first.fetch("refresh_token")
    }

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body).fetch("error")
    assert_not_nil approved.fetch(:authorization).reload.revoked_at
    assert_not_nil approved.fetch(:access_recording).reload.trashed_at

    post api_token_path, params: {
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: rotated.fetch("refresh_token")
    }
    assert_response :bad_request
  end

  test "a revoked unrotated refresh token is invalid_grant and leaves newer tokens live" do
    first = approve_and_exchange(@pkce)
    second_pkce = pkce_pair
    second = approve_and_exchange(second_pkce)

    stale = refresh_record(first.fetch(:issued).fetch("refresh_token"))
    stale.revoke!
    refute stale.rotated?

    post api_token_path, params: {
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: first.fetch(:issued).fetch("refresh_token")
    }

    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body).fetch("error")
    assert_nil first.fetch(:authorization).reload.revoked_at
    assert_nil first.fetch(:authorization).access_recording.reload.trashed_at
    assert_workspaces_with(second.fetch(:issued).fetch("access_token"))

    post api_token_path, params: {
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: second.fetch(:issued).fetch("refresh_token")
    }

    assert_response :success
    assert_nil first.fetch(:authorization).reload.revoked_at
  end

  test "re-consent can raise the role without dropping live tokens" do
    first = approve_and_exchange(@pkce, role: "view")
    assert_equal "view", first.fetch(:authorization).role

    second_pkce = pkce_pair
    second = approve_and_exchange(second_pkce, role: "edit")

    assert_equal "edit", second.fetch(:authorization).reload.role
    assert_equal "edit", second.fetch(:authorization).access_recording.recordable.role.to_s
    assert_workspaces_with(first.fetch(:issued).fetch("access_token"))
  end

  private

  def approve_and_exchange(pkce, role: "view")
    approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      role: role,
      pkce: pkce
    )
    issued = exchange_authorization_code(
      client_id: @oauth_client.client_id,
      code: approved.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: pkce.fetch(:verifier)
    )
    { authorization: approved.fetch(:authorization), issued: issued }
  end

  def exchange_authorization_code(client_id:, code:, redirect_uri:, code_verifier:)
    post api_token_path, params: {
      grant_type: "authorization_code",
      client_id: client_id,
      code: code,
      redirect_uri: redirect_uri,
      code_verifier: code_verifier
    }
    assert_response :success
    JSON.parse(response.body)
  end

  def refresh_record(token)
    RecordingStudioOauth::OauthRefreshToken.find_by!(
      token_digest: RecordingStudioOauth::TokenDigest.digest(token)
    )
  end

  def assert_workspaces_with(access_token)
    get "/recording_studio_api/api/v1/workspaces",
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Accept" => "application/json"
        }

    assert_response :success
    ids = JSON.parse(response.body).fetch("records").map { |row| row.fetch("id") }
    assert_includes ids, @root_recording.id
  end
end
