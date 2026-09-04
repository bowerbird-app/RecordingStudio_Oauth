# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class OauthAuthorizeLoginReturnTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include OauthDummyHelpers

  setup do
    @user = create_user(email: "oauth-login-return@example.com")
    @root, = create_access_recording_for(user: @user, workspace_name: "Login Return Workspace")
    @oauth_client, = create_oauth_client(name: "Login Return App")
    @authorize_params = {
      response_type: "code",
      client_id: @oauth_client.client_id,
      redirect_uri: "http://127.0.0.1/callback",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge("V" + ("a" * 42)),
      code_challenge_method: "S256",
      state: "return-me"
    }
  end

  test "unauthenticated authorize lands on Users email screen with social" do
    get authorize_path, params: @authorize_params

    assert_redirected_to new_user_session_path
    follow_redirect!

    assert_response :success
    assert_select "h2", text: "Welcome back"
    assert_select "button[type='submit']", text: "Continue with email"
    assert_select "button[type='submit']", text: "Continue with Google"
    assert_select "input[type='password']", count: 0
  end

  test "preferred path password screen then returns to Connect" do
    get authorize_path, params: @authorize_params
    assert_redirected_to new_user_session_path
    follow_redirect!

    post new_user_session_path, params: { user: { email: @user.email } }
    assert_redirected_to "/users/sign_in/password"
    follow_redirect!

    assert_response :success
    assert_select "input[type='password'][name='user[password]']"
    assert_select "button[type='submit']", text: "Sign in"
    assert_select "button[type='submit']", text: "Continue with Google", count: 0

    post user_session_path, params: { user: { email: @user.email, password: TEST_PASSWORD } }
    follow_redirect!

    assert_response :success
    assert_match(%r{/recording_studio_oauth/oauth/authorize}, request.path)
    assert_includes response.body, "Login Return App"
    assert_includes response.body, "wants to connect"
  end
end
