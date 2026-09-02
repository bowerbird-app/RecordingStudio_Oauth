# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DelegatedOauthTest < ActionDispatch::IntegrationTest
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

  test "screen 1 lists parent names and skips AdminRoot" do
    folder_name = "Product Docs"
    _root, folder_recording, folder_access = create_folder_access_for(
      user: @user,
      folder_name: folder_name
    )
    second_root, = create_access_recording_for(user: @user, workspace_name: "Docs Workspace")
    _admin_root, admin_root_recording = create_admin_root_recording
    admin_root_access = grant_or_bootstrap_access!(
      recording: admin_root_recording,
      actor: @user,
      role: :admin
    )

    get authorize_path, params: authorize_params

    assert_response :success
    assert_select "body[data-theme='rounded']", count: 1
    refute_includes response.body, "data-recording-studio-default-layout"
    assert_includes response.body, "min-h-dvh"
    assert_includes response.body, "max-w-sm"
    assert_select ".flat-pack-page-nav", count: 0
    assert_includes response.body, "#{@oauth_client.name} wants to connect"
    refute_match(/wants to connect to\s*</, response.body)
    refute_includes response.body, "It gets its own access here. Yours stays yours."
    refute_includes response.body, "Connect #{@oauth_client.name}"
    assert_includes response.body, @root_recording.recordable.name
    assert_select "label", text: "Workspace", count: 0
    assert_select "select[name='access_recording_id']", count: 0
    assert_select "button[name='decision'][value='continue']", count: 0
    assert_select "button[name='decision'][value='connect']", count: 0
    assert_includes response.body, "p-[var(--card-padding-md)]"
    assert_select "[role='list']"
    assert_select "[role='list'] [role='list']", count: 0
    labels = css_select("[role='listitem'] p").map { |node| node.text.strip }
    assert_includes labels, @root_recording.recordable.name
    assert_includes labels, second_root.recordable.name
    assert_includes labels, folder_name
    assert_equal labels.length, labels.uniq.length
    %w[Admin View Edit].each { |role_label| refute_includes labels, role_label }
    assert_not_includes labels, admin_root_recording.recordable.name
    assert_not_includes response.body, "access_recording_id=#{admin_root_access.id}"
    assert_includes response.body, "access_recording_id=#{folder_access.id}"
    assert_includes response.body, "access_recording_id=#{@access_recording.id}"
    assert_select "[role='listitem'] a[href*='access_recording_id']"
    css_select("[role='listitem']").each do |item|
      assert_match(/\bConnect(ed)?\b|\bReconnect\b/, item.text)
    end
    assert_match(/\bConnect\b/, css_select("[role='listitem']").find { |item| item.text.include?(folder_name) }.text)
    folder_button = css_select("[role='listitem']").find { |item| item.text.include?(folder_name) }.at_css("a")
    assert_includes folder_button["class"], "--button-default-background-color"
    refute_equal @root_recording.id, folder_recording.id
    assert_select "[data-controller='recording-studio-root-switchable--root-switch-dropdown']", count: 0
    assert_not_includes response.body, "Sign out"
  end

  test "shared site name is the handshake title" do
    other_root, = create_access_recording_for(user: @user, workspace_name: "Docs Workspace")
    seed_site_name!(@root_recording, name: "Studio", actor: @user)
    seed_site_name!(other_root, name: "Studio", actor: @user)

    get authorize_path, params: authorize_params

    assert_response :success
    assert_includes response.body, "#{@oauth_client.name} wants to connect to Studio"
    labels = css_select("[role='listitem'] p").map { |node| node.text.strip }
    assert_includes labels, @root_recording.recordable.name
    assert_includes labels, other_root.recordable.name
    refute_equal ["Studio"], labels.uniq
  end

  test "different site names put name_for on each row" do
    other_root, = create_access_recording_for(user: @user, workspace_name: "Docs Workspace")
    seed_site_name!(@root_recording, name: "Harbor", actor: @user)
    seed_site_name!(other_root, name: "Meadow", actor: @user)

    get authorize_path, params: authorize_params

    assert_response :success
    assert_includes response.body, "#{@oauth_client.name} wants to connect"
    refute_includes response.body, "wants to connect to Harbor"
    refute_includes response.body, "wants to connect to Meadow"
    labels = css_select("[role='listitem'] p").map { |node| node.text.strip }
    assert_includes labels, "Harbor"
    assert_includes labels, "Meadow"
  end

  test "permission screen uses the picked parent name" do
    seed_site_name!(@root_recording, name: "Studio", actor: @user)

    get authorize_path, params: authorize_params.merge(access_recording_id: @access_recording.id)

    assert_response :success
    assert_includes response.body, "#{@root_recording.recordable.name} permissions"
    refute_includes response.body, "wants to connect"
    refute_includes response.body, @oauth_client.name
    assert_select "label", count: 0
    refute_includes response.body, "You can view"
    assert_select ".flat-pack-page-nav", count: 1
  end

  test "screen 2 connect issues a code and token pair" do
    get authorize_path, params: authorize_params.merge(access_recording_id: @access_recording.id)

    assert_response :success
    assert_includes response.body, "#{@root_recording.recordable.name} permissions"
    refute_includes response.body, "wants to connect"
    assert_select "input[name='access_recording_id'][value=?]", @access_recording.id
    assert_select "label", count: 0
    refute_includes response.body, "You can view"
    assert_select "button[name='decision'][value='connect']"
    assert_select "button[name='decision'][value='cancel']"
    assert_select ".flat-pack-page-nav", count: 1

    post authorize_path, params: authorize_params.merge(
      access_recording_id: @access_recording.id,
      role: "view",
      decision: "connect"
    )

    assert_response :redirect
    code = code_from_redirect
    assert_match(/\Arsoauth_ac_/, code)

    post api_token_path, params: {
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: code,
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: @pkce.fetch(:verifier)
    }

    assert_response :success
    issued = JSON.parse(response.body)
    assert_match(/\Arsoauth_at_/, issued.fetch("access_token"))
    assert_match(/\Arsoauth_rt_/, issued.fetch("refresh_token"))
  end

  test "cancel redirects to the client with access_denied" do
    assert_no_difference -> { RecordingStudioOauth::OauthAuthorization.where(oauth_client: @oauth_client).count } do
      post authorize_path, params: authorize_params.merge(
        access_recording_id: @access_recording.id,
        role: "view",
        decision: "cancel"
      )
    end

    assert_response :redirect
    query = redirect_query
    assert_equal "access_denied", query.fetch("error")
    assert_equal "xyz", query.fetch("state")
  end

  test "grant on folder access is a sibling of that access and depends on it" do
    folder_user = create_user(email: "folder-only-oauth@example.com")
    root_recording, folder_recording, folder_access = create_folder_access_for(
      user: folder_user,
      folder_name: "Release Notes",
      role: :admin
    )
    sign_in folder_user

    post authorize_path, params: authorize_params.merge(
      access_recording_id: folder_access.id,
      role: "view",
      decision: "continue"
    )

    assert_response :redirect
    authorization = RecordingStudioOauth::OauthAuthorization.find_by!(manager_actor: folder_user, oauth_client: @oauth_client)
    granted = authorization.access_recording

    assert_equal folder_recording.id, granted.parent_recording_id
    refute_equal root_recording.id, granted.parent_recording_id
    assert_equal folder_access.id, granted.recordable.depends_on_recording_id
    assert_equal folder_access.id, authorization.manager_access_recording_id
  end

  test "same client and access reconnect does not stack a second grant" do
    first = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )
    first_granted_id = first.fetch(:access_recording).id

    post authorize_path, params: authorize_params.merge(
      access_recording_id: @access_recording.id,
      role: "view",
      decision: "continue"
    )

    assert_response :redirect
    authorizations = RecordingStudioOauth::OauthAuthorization.where(
      oauth_client: @oauth_client,
      manager_actor: @user,
      manager_access_recording: @access_recording
    )

    assert_equal 1, authorizations.count
    assert_equal first.fetch(:authorization).id, authorizations.first.id
    assert_not_nil RecordingStudio::Recording.unscoped.find(first_granted_id).trashed_at
    assert_not_nil authorizations.first.access_recording
    refute_equal first_granted_id, authorizations.first.access_recording_id
    assert_nil authorizations.first.access_recording.trashed_at
    assert_equal @access_recording.id, authorizations.first.access_recording.recordable.depends_on_recording_id
  end

  test "two workspaces create two authorizations and two tokens" do
    _second_root, second_access = create_access_recording_for(user: @user, workspace_name: "Second workspace")
    first_pkce = @pkce
    second_pkce = pkce_pair

    first = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: first_pkce
    )
    second = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: second_access,
      pkce: second_pkce
    )

    first_token = exchange_authorization_code(
      client_id: @oauth_client.client_id,
      code: first.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: first_pkce.fetch(:verifier)
    )
    second_token = exchange_authorization_code(
      client_id: @oauth_client.client_id,
      code: second.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: second_pkce.fetch(:verifier)
    )

    refute_equal first_token.fetch("access_token"), second_token.fetch("access_token")
    assert_equal 2, RecordingStudioOauth::OauthAuthorization.where(oauth_client: @oauth_client, manager_actor: @user).count
  end

  test "edit over current role rejects and points at reconnect without clamping" do
    approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      role: "admin",
      pkce: @pkce
    )
    RecordingStudioAccessible::AccessCreationContext.allow do
      RecordingStudio.root_recording_or_self(@access_recording).revise(@access_recording, actor: @user) do |access|
        access.role = :view
      end
    end

    assert_no_difference -> { RecordingStudioOauth::OauthAuthorization.where(oauth_client: @oauth_client, manager_actor: @user).count } do
      post authorize_path, params: authorize_params.merge(
        access_recording_id: @access_recording.id,
        role: "admin",
        decision: "continue"
      )
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Your access changed. Connect again."
    assert_select "button[name='decision'][value='connect']", count: 0
    authorization = RecordingStudioOauth::OauthAuthorization.find_by!(oauth_client: @oauth_client, manager_actor: @user)
    assert_equal "admin", authorization.role
  end

  test "edit with access gone rejects and points at reconnect" do
    approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )
    stale_access_id = @access_recording.id
    @access_recording.update!(trashed_at: Time.current)

    assert_no_difference -> { RecordingStudioOauth::OauthAuthorization.where(oauth_client: @oauth_client, manager_actor: @user).count } do
      post authorize_path, params: authorize_params.merge(
        access_recording_id: stale_access_id,
        role: "view",
        decision: "continue"
      )
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "That access is gone. Connect again."
    assert_select "button[name='decision'][value='connect']", count: 0
  end

  test "view-only screen 2 has no permission select" do
    view_user = create_user(email: "view-only-oauth@example.com")
    _root, view_access = create_access_recording_for(user: view_user, role: :view)
    sign_in view_user

    get authorize_path, params: authorize_params.merge(access_recording_id: view_access.id)

    assert_response :success
    assert_includes response.body, "#{view_access.parent_recording.recordable.name} permissions"
    assert_select "label", count: 0
    assert_select "input[name='role'][value=view]"
    assert_select "button[name='decision'][value='connect']"
    assert_select "button[name='decision'][value='cancel']"
  end

  test "screen 1 shows connected and reconnect states" do
    approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )
    _second_root, second_access = create_access_recording_for(user: @user, workspace_name: "Reconnect workspace")
    reconnect_grant = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: second_access
    )
    RecordingStudioOauth::Services::VoidOauthAuthorization.call(authorization: reconnect_grant.fetch(:authorization))

    get authorize_path, params: authorize_params

    assert_response :success
    connected_button = css_select("[role='listitem']").find { |item| item.text.include?(@root_recording.recordable.name) }.at_css("a")
    reconnect_button = css_select("[role='listitem']").find { |item| item.text.include?("Reconnect workspace") }.at_css("a")
    assert_equal "Connected", connected_button.text.strip
    assert_equal "Reconnect", reconnect_button.text.strip
    assert_includes connected_button["class"], "--button-success-background-color"
    assert_includes reconnect_button["class"], "--button-danger-background-color"
  end

  test "authorization code reuse voids the grant" do
    approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )
    token_params = {
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: approved.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: @pkce.fetch(:verifier)
    }

    post api_token_path, params: token_params
    assert_response :success

    post api_token_path, params: token_params
    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body).fetch("error")
    assert_not_nil approved.fetch(:authorization).reload.revoked_at
    assert_not_nil approved.fetch(:access_recording).reload.trashed_at
  end

  test "refresh token rotation issues a new token and rejects the old refresh token" do
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
    refute_equal first.fetch("access_token"), rotated.fetch("access_token")

    post api_token_path, params: {
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: first.fetch("refresh_token")
    }
    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body).fetch("error")
  end

  test "PKCE S256 is required for public clients" do
    get authorize_path, params: authorize_params.except(:code_challenge, :code_challenge_method)

    assert_response :redirect
    assert_equal "invalid_request", redirect_query.fetch("error")
  end

  test "boot registers authorization_code and refresh_token on the API grant hook" do
    grants = RecordingStudioApi.oauth_grants

    assert_equal RecordingStudioOauth::DelegatedGrant, grants.fetch("authorization_code")
    assert_equal RecordingStudioOauth::DelegatedGrant, grants.fetch("refresh_token")
    refute grants.key?("client_credentials")
  end

  test "this gem does not mount a second token endpoint" do
    post "/recording_studio_oauth/oauth/token", params: {
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: "rsoauth_ac_unused"
    }

    assert_response :not_found
  end

  test "client_credentials still issues a machine token on the API token URL" do
    payload = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_recording: @access_recording,
      name: "Machine client"
    )
    assert payload.success?, payload.error

    post api_token_path, params: {
      grant_type: "client_credentials",
      client_id: payload.value.fetch(:credential).oauth_client_id,
      client_secret: payload.value.fetch(:token)
    }

    assert_response :success
    body = JSON.parse(response.body)
    assert_match(/\Arsapi_at_/, body.fetch("access_token"))
    refute_match(/\Arsoauth_at_/, body.fetch("access_token"))
  end

  test "discovery documents point authorize here and token at the API" do
    get "/recording_studio_oauth/.well-known/oauth-authorization-server"

    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body.fetch("authorization_endpoint"), "/recording_studio_oauth/oauth/authorize"
    assert_includes body.fetch("token_endpoint"), "/recording_studio_api/oauth/token"
    assert_includes body.fetch("grant_types_supported"), "authorization_code"
    assert_includes body.fetch("grant_types_supported"), "refresh_token"
    assert_equal ["S256"], body.fetch("code_challenge_methods_supported")

    get "/.well-known/oauth-authorization-server"
    assert_response :success
    assert_includes JSON.parse(response.body).fetch("token_endpoint"), "/recording_studio_api/oauth/token"
  end

  test "access grant actor is the authorization not the user" do
    approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      pkce: @pkce
    )
    granted = approved.fetch(:access_recording).recordable

    assert_equal "RecordingStudioOauth::OauthAuthorization", granted.actor_type
    assert_equal approved.fetch(:authorization).id, granted.actor_id
    refute_equal @user.id, granted.actor_id
  end

  test "error screen uses the login frame not a two-column grid" do
    get authorize_path, params: authorize_params.merge(response_type: "token")

    assert_response :bad_request
    assert_includes response.body, "Could not connect"
    assert_includes response.body, "response_type must be code"
    assert_includes response.body, "min-h-dvh"
    assert_includes response.body, "max-w-sm"
    refute_includes response.body, "data-recording-studio-default-layout"
    assert_select ".flat-pack-page-nav", count: 1
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

  def code_from_redirect
    redirect_query.fetch("code")
  end

  def redirect_query
    URI.decode_www_form(URI.parse(response.redirect_url).query.to_s).to_h
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
end
