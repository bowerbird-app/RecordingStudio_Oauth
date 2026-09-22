# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "uri"

class CentralRelayTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  PATTERN = "https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback"

  setup do
    @user = create_user
    @root_recording, @access_recording = create_access_recording_for(user: @user)
    @pkce = pkce_pair
    @return_to = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    @other_return = "https://other.example/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    @relay_url = central_callback_url
    @oauth_client, = create_oauth_client(
      name: "Relay App",
      redirect_uris: [@relay_url],
      use_central_relay: true,
      allowed_return_patterns: [PATTERN]
    )
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "connect start relays the code back to the matching return address" do
    get central_connect_path, params: start_params

    assert_response :redirect
    authorize_query = query_from(response.redirect_url)
    assert_includes response.redirect_url, authorize_path
    assert_equal @relay_url, authorize_query.fetch("redirect_uri")
    assert_equal @pkce.fetch(:challenge), authorize_query.fetch("code_challenge")
    assert_equal "S256", authorize_query.fetch("code_challenge_method")
    refute_equal @return_to, authorize_query.fetch("redirect_uri")

    post authorize_path, params: authorize_query.merge(
      "access_recording_id" => @access_recording.id,
      "role" => "view",
      "decision" => "connect"
    )

    assert_response :redirect
    relay_query = query_from(response.redirect_url)
    assert_equal URI.parse(@relay_url).path, URI.parse(response.redirect_url).path
    assert relay_query["code"].present?

    get central_callback_path, params: relay_query.merge("return_to" => "https://evil.example/")

    assert_response :redirect
    returned = query_from(response.redirect_url)
    assert_equal URI.parse(@return_to).host, URI.parse(response.redirect_url).host
    assert_equal "/wp-admin/admin-post.php", URI.parse(response.redirect_url).path
    assert_equal "recording_studio_oauth_callback", returned.fetch("action")
    assert_equal relay_query.fetch("code"), returned.fetch("code")
    assert_equal "site-csrf", returned.fetch("state")
    refute_includes response.redirect_url, "evil.example"

    tokens = exchange_authorization_code(
      client_id: @oauth_client.client_id,
      code: returned.fetch("code"),
      redirect_uri: @relay_url,
      code_verifier: @pkce.fetch(:verifier)
    )
    assert tokens.fetch("access_token").start_with?("rsoauth_at_")
  end

  test "start accepts an exact return URL and rejects a different address" do
    exact = "https://shop.example.com/oauth/done"
    @oauth_client.update!(allowed_return_patterns: [], exact_return_urls: [exact])

    get central_connect_path, params: start_params(return_to: exact)
    assert_response :redirect

    get central_connect_path, params: start_params(return_to: "https://shop.example.com/oauth/other")
    assert_response :bad_request
    assert_includes response.body, "That return address is not allowed."
  end

  test "start rejects an open redirect return_to" do
    get central_connect_path, params: start_params.merge(return_to: "https://evil.example/steal")

    assert_response :bad_request
    assert_includes response.body, "That return address is not allowed."
    refute_response_redirect_to_host "evil.example"
  end

  test "start rejects an unknown client_id" do
    get central_connect_path, params: start_params.merge(client_id: "unknown-client")

    assert_response :unauthorized
    assert_includes response.body, "This app is not registered."
  end

  test "a relay off client cannot start connect or leave through the central callback" do
    off_client, = create_oauth_client(name: "Plain App", redirect_uris: [@relay_url], use_central_relay: false)

    get central_connect_path, params: start_params.merge(client_id: off_client.client_id)
    assert_response :bad_request
    assert_includes response.body, "This app is not set up for the central relay."

    get authorize_path, params: {
      response_type: "code",
      client_id: off_client.client_id,
      redirect_uri: @relay_url,
      state: "attacker",
      code_challenge: @pkce.fetch(:challenge),
      code_challenge_method: "S256"
    }
    assert_response :success

    post authorize_path, params: {
      response_type: "code",
      client_id: off_client.client_id,
      redirect_uri: @relay_url,
      state: "attacker",
      code_challenge: @pkce.fetch(:challenge),
      code_challenge_method: "S256",
      access_recording_id: @access_recording.id,
      role: "view",
      decision: "connect"
    }

    assert_response :redirect
    follow_redirect!
    assert_response :bad_request
    assert_includes response.body, "This Connect return is not valid. Start again."
    refute_includes response.body, "blog.example.com"
  end

  test "token exchange rejects the client return address as redirect_uri" do
    issued = start_and_issue_code
    get central_callback_path, params: issued
    returned = query_from(response.redirect_url)

    post api_token_path, params: {
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: returned.fetch("code"),
      redirect_uri: @return_to,
      code_verifier: @pkce.fetch(:verifier)
    }

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal "invalid_grant", body.fetch("error")
    assert_equal "redirect_uri does not match", body.fetch("error_description")
  end

  test "callback rejects a code bound to a different return" do
    site_a = start_and_issue_code(return_to: @return_to, state: "site-a")
    site_b = start_authorize_query(return_to: @other_return, state: "site-b", pkce: pkce_pair)

    get central_callback_path, params: {
      code: site_a.fetch("code"),
      state: site_b.fetch("state"),
      return_to: @other_return
    }

    assert_response :bad_request
    assert_includes response.body, "This Connect return is not valid. Start again."
    refute_response_redirect_to_host "other.example"
  end

  test "legacy wordpress relay paths are not routed" do
    get "/recording_studio_oauth/wordpress/connect", params: start_params
    assert_response :not_found

    get "/recording_studio_oauth/wordpress/callback"
    assert_response :not_found
  end

  private

  def central_connect_path
    "/recording_studio_oauth/connect"
  end

  def central_callback_path
    "/recording_studio_oauth/callback"
  end

  def central_callback_url
    "http://www.example.com/recording_studio_oauth/callback"
  end

  def start_params(return_to: @return_to, state: "site-csrf", pkce: @pkce)
    {
      client_id: @oauth_client.client_id,
      return_to: return_to,
      state: state,
      code_challenge: pkce.fetch(:challenge),
      code_challenge_method: "S256",
      response_type: "code"
    }
  end

  def start_authorize_query(**overrides)
    get central_connect_path, params: start_params(**overrides)
    assert_response :redirect
    query_from(response.redirect_url)
  end

  def start_and_issue_code(**overrides)
    authorize_query = start_authorize_query(**overrides)
    post authorize_path, params: authorize_query.merge(
      "access_recording_id" => @access_recording.id,
      "role" => "view",
      "decision" => "connect"
    )
    assert_response :redirect
    query_from(response.redirect_url)
  end

  def query_from(url)
    URI.decode_www_form(URI.parse(url).query.to_s).to_h
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

  def refute_response_redirect_to_host(host)
    return unless response.redirect?

    refute_includes response.redirect_url, host
  end
end
