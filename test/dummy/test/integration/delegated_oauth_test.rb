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
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "title", text: /Connect #{Regexp.escape(@oauth_client.name)}/
    assert_includes response.body, "It gets its own access here. Yours stays yours."
    assert_includes response.body, @root_recording.recordable.name
    assert_select "label", text: "Workspace", count: 0
    assert_select "select[name='access_recording_id']", count: 0
    assert_select "button[name='decision'][value='continue']", count: 0
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
    css_select("[role='listitem']").each do |item|
      assert_match(/\bConnect(ed)?\b|\bReconnect\b/, item.text)
    end
    assert_match(/\bConnect\b/, css_select("[role='listitem']").find { |item| item.text.include?(folder_name) }.text)
    refute_equal @root_recording.id, folder_recording.id
    assert_select "[data-controller='recording-studio-root-switchable--root-switch-dropdown']", count: 0
    assert_not_includes response.body, "Sign out"
  end

  test "screen 2 continue issues a code and token pair" do
    get authorize_path, params: authorize_params.merge(access_recording_id: @access_recording.id)

    assert_response :success
    assert_includes response.body, "Connect #{@oauth_client.name}"
    assert_includes response.body, @root_recording.recordable.name
    assert_select "input[name='access_recording_id'][value=?]", @access_recording.id
    assert_select "label", text: "Permission"
    assert_select "button[name='decision'][value='continue']"
    assert_select "button[name='decision'][value='cancel']"

    post authorize_path, params: authorize_params.merge(
      access_recording_id: @access_recording.id,
      role: "view",
      decision: "continue"
    )

    assert_response :redirect
    code = code_from_redirect
    assert_match(/\Arsoauth_ac_/, code)

    issued = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: code,
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: @pkce.fetch(:verifier)
    )

    assert issued.success?, issued.error
    assert_match(/\Arsoauth_at_/, issued.value.fetch(:access_token))
    assert_match(/\Arsoauth_rt_/, issued.value.fetch(:refresh_token))
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

    first_token = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: first.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: first_pkce.fetch(:verifier)
    )
    second_token = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: second.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: second_pkce.fetch(:verifier)
    )

    assert first_token.success?, first_token.error
    assert second_token.success?, second_token.error
    refute_equal first_token.value.fetch(:access_token), second_token.value.fetch(:access_token)
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
    assert_select "button[name='decision'][value='continue']", count: 0
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
    assert_select "button[name='decision'][value='continue']", count: 0
  end

  test "view-only screen 2 has no permission select" do
    view_user = create_user(email: "view-only-oauth@example.com")
    _root, view_access = create_access_recording_for(user: view_user, role: :view)
    sign_in view_user

    get authorize_path, params: authorize_params.merge(access_recording_id: view_access.id)

    assert_response :success
    assert_select "label", text: "Permission", count: 0
    assert_select "input[name='role'][value=view]"
    assert_select "button[name='decision'][value='continue']"
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
    reconnect = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: second_access
    )
    RecordingStudioOauth::Services::VoidOauthAuthorization.call(authorization: reconnect.fetch(:authorization))

    get authorize_path, params: authorize_params

    assert_response :success
    assert_includes response.body, "Connected"
    assert_includes response.body, "Reconnect"
    assert_includes response.body, "Connect"
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

    first = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(**token_params)
    assert first.success?, first.error

    second = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(**token_params)
    assert second.failure?
    assert_equal "invalid_grant", second.error.fetch(:error)
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
    first = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "authorization_code",
      client_id: @oauth_client.client_id,
      code: approved.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: @pkce.fetch(:verifier)
    )
    assert first.success?, first.error

    rotated = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: first.value.fetch(:refresh_token)
    )
    assert rotated.success?, rotated.error
    refute_equal first.value.fetch(:access_token), rotated.value.fetch(:access_token)

    reused = RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
      grant_type: "refresh_token",
      client_id: @oauth_client.client_id,
      refresh_token: first.value.fetch(:refresh_token)
    )
    assert reused.failure?
    assert_equal "invalid_grant", reused.error.fetch(:error)
  end

  test "PKCE S256 is required for public clients" do
    get authorize_path, params: authorize_params.except(:code_challenge, :code_challenge_method)

    assert_response :redirect
    assert_equal "invalid_request", redirect_query.fetch("error")
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
end
