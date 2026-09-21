# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "uri"

class WordPressRelayTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    @root_recording, @access_recording = create_access_recording_for(user: @user)
    @pkce = pkce_pair
    @return_to = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    @other_return = "https://evil.example/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    @relay_url = wordpress_callback_url
    @oauth_client, = create_oauth_client(name: "WordPress", redirect_uris: [@relay_url])
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "connect start relays the code back to the originating wordpress callback" do
    get wordpress_connect_path, params: start_params

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

    get wordpress_callback_path, params: relay_query.merge("return_to" => "https://evil.example/")

    assert_response :redirect
    wp_query = query_from(response.redirect_url)
    assert_equal URI.parse(@return_to).host, URI.parse(response.redirect_url).host
    assert_equal "/wp-admin/admin-post.php", URI.parse(response.redirect_url).path
    assert_equal "recording_studio_oauth_callback", wp_query.fetch("action")
    assert_equal relay_query.fetch("code"), wp_query.fetch("code")
    assert_equal "wp-csrf", wp_query.fetch("state")
    refute_includes response.redirect_url, "evil.example"

    tokens = exchange_authorization_code(
      client_id: @oauth_client.client_id,
      code: wp_query.fetch("code"),
      redirect_uri: @relay_url,
      code_verifier: @pkce.fetch(:verifier)
    )
    assert tokens.fetch("access_token").start_with?("rsoauth_at_")
  end

  test "start rejects an open redirect return_to" do
    get wordpress_connect_path, params: start_params.merge(return_to: "https://evil.example/steal")

    assert_response :bad_request
    assert_includes response.body, "That WordPress return address is not allowed."
    refute_response_redirect_to_host "evil.example"
  end

  test "start rejects an unknown client_id" do
    get wordpress_connect_path, params: start_params.merge(client_id: "unknown-client")

    assert_response :unauthorized
    assert_includes response.body, "This app is not registered."
  end

  test "token exchange rejects the wordpress admin-post as redirect_uri" do
    issued = start_and_issue_code
    get wordpress_callback_path, params: issued
    wp_query = query_from(response.redirect_url)

    post api_token_path, params: {
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: wp_query.fetch("code"),
      redirect_uri: @return_to,
      code_verifier: @pkce.fetch(:verifier)
    }

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal "invalid_grant", body.fetch("error")
    assert_equal "redirect_uri does not match", body.fetch("error_description")
  end

  test "callback rejects a code bound to a different wordpress return" do
    site_a = start_and_issue_code(return_to: @return_to, state: "site-a")
    site_b = start_authorize_query(return_to: @other_return, state: "site-b", pkce: pkce_pair)

    get wordpress_callback_path, params: {
      code: site_a.fetch("code"),
      state: site_b.fetch("state"),
      return_to: @other_return
    }

    assert_response :bad_request
    assert_includes response.body, "This Connect return is not valid. Start again from WordPress."
    refute_response_redirect_to_host "evil.example"
  end

  private

  def wordpress_connect_path
    "/recording_studio_oauth/wordpress/connect"
  end

  def wordpress_callback_path
    "/recording_studio_oauth/wordpress/callback"
  end

  def wordpress_callback_url
    "http://www.example.com/recording_studio_oauth/wordpress/callback"
  end

  def start_params(return_to: @return_to, state: "wp-csrf", pkce: @pkce)
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
    get wordpress_connect_path, params: start_params(**overrides)
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
