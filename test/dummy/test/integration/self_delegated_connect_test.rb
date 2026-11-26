# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SelfDelegatedConnectTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @pkce = pkce_pair
    @oauth_client, = create_oauth_client
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "an edit member can connect at edit or view" do
    editor = create_user(email: "edit-member-connect@example.com")
    root_recording, edit_access = create_access_recording_for(user: editor, role: :edit)
    sign_in editor

    view_client, = create_oauth_client(name: "View Connect App")
    view_result = connect_as(
      user: editor,
      oauth_client: view_client,
      access_recording: edit_access,
      role: "view"
    )
    edit_result = connect_as(
      user: editor,
      oauth_client: @oauth_client,
      access_recording: edit_access,
      role: "edit"
    )

    assert view_result.success?, view_result.error.to_s
    assert edit_result.success?, edit_result.error.to_s
    assert_equal "view", view_result.value.fetch(:authorization).role
    assert_equal "edit", edit_result.value.fetch(:authorization).role
    assert_equal "view", view_result.value.fetch(:access_recording).recordable.role
    assert_equal "edit", edit_result.value.fetch(:access_recording).recordable.role
    assert_equal edit_access.id, edit_result.value.fetch(:access_recording).recordable.depends_on_recording_id
    assert RecordingStudioAccessible.authorized?(
      actor: edit_result.value.fetch(:authorization),
      recording: root_recording,
      role: :edit
    )
  end

  test "an edit member is refused at admin" do
    editor = create_user(email: "edit-member-admin-refused@example.com")
    _root, edit_access = create_access_recording_for(user: editor, role: :edit)

    result = connect_as(
      user: editor,
      oauth_client: @oauth_client,
      access_recording: edit_access,
      role: "admin"
    )

    refute result.success?
    assert_equal RecordingStudioOauth::Services::CreateOauthAuthorization.role_changed_message, result.error.to_s
    assert_nil RecordingStudioOauth::OauthAuthorization.find_by(oauth_client: @oauth_client, manager_actor: editor)
  end

  test "a view member can connect at view" do
    viewer = create_user(email: "view-member-connect@example.com")
    root_recording, view_access = create_access_recording_for(user: viewer, role: :view)

    result = connect_as(
      user: viewer,
      oauth_client: @oauth_client,
      access_recording: view_access,
      role: "view"
    )

    assert result.success?, result.error.to_s
    authorization = result.value.fetch(:authorization)
    granted = result.value.fetch(:access_recording)
    assert_equal "view", authorization.role
    assert_equal "view", granted.recordable.role
    assert_equal view_access.id, granted.recordable.depends_on_recording_id
    assert_equal root_recording.id, granted.parent_recording_id
  end

  test "a non-member is refused" do
    owner = create_user(email: "non-member-owner@example.com")
    _root, owner_access = create_access_recording_for(user: owner, role: :admin)
    stranger = create_user(email: "non-member-stranger@example.com")

    result = connect_as(
      user: stranger,
      oauth_client: @oauth_client,
      access_recording: owner_access,
      role: "view"
    )

    refute result.success?
    assert_equal RecordingStudioAccessible::Copy.t("errors.self_delegated_not_a_member"), result.error.to_s
    assert_nil RecordingStudioOauth::OauthAuthorization.find_by(oauth_client: @oauth_client, manager_actor: stranger)
  end

  test "same-role reconnect reuses the grant" do
    editor = create_user(email: "edit-member-reconnect@example.com")
    _root, edit_access = create_access_recording_for(user: editor, role: :edit)
    first = connect_as(
      user: editor,
      oauth_client: @oauth_client,
      access_recording: edit_access,
      role: "edit"
    )
    assert first.success?, first.error.to_s
    first_grant_id = first.value.fetch(:access_recording).id

    second = connect_as(
      user: editor,
      oauth_client: @oauth_client,
      access_recording: edit_access,
      role: "edit"
    )

    assert second.success?, second.error.to_s
    authorizations = RecordingStudioOauth::OauthAuthorization.where(
      oauth_client: @oauth_client,
      manager_actor: editor,
      manager_access_recording: edit_access
    )
    assert_equal 1, authorizations.count
    assert_equal first.value.fetch(:authorization).id, second.value.fetch(:authorization).id
    assert_equal first_grant_id, second.value.fetch(:access_recording).id
    assert second.value.fetch(:access_recording).recording_studio_trashable_kept?
  end

  test "reconnect at a different role updates the grant in place and refuses a role above the member" do
    editor = create_user(email: "edit-member-role-change@example.com")
    root_recording, edit_access = create_access_recording_for(user: editor, role: :edit)
    first = connect_as(
      user: editor,
      oauth_client: @oauth_client,
      access_recording: edit_access,
      role: "view"
    )
    assert first.success?, first.error.to_s
    first_grant = first.value.fetch(:access_recording)

    second = connect_as(
      user: editor,
      oauth_client: @oauth_client,
      access_recording: edit_access,
      role: "edit"
    )

    assert second.success?, second.error.to_s
    authorizations = RecordingStudioOauth::OauthAuthorization.where(
      oauth_client: @oauth_client,
      manager_actor: editor,
      manager_access_recording: edit_access
    )
    assert_equal 1, authorizations.count
    assert_equal first.value.fetch(:authorization).id, second.value.fetch(:authorization).id
    assert_equal first_grant.id, second.value.fetch(:access_recording).id
    assert_equal "edit", second.value.fetch(:authorization).role
    assert_equal "edit", second.value.fetch(:access_recording).recordable.role
    assert second.value.fetch(:access_recording).recording_studio_trashable_kept?
    assert RecordingStudioAccessible.authorized?(
      actor: second.value.fetch(:authorization),
      recording: root_recording,
      role: :edit
    )

    refused = connect_as(
      user: editor,
      oauth_client: @oauth_client,
      access_recording: edit_access,
      role: "admin"
    )

    refute refused.success?
    assert_equal RecordingStudioOauth::Services::CreateOauthAuthorization.role_changed_message, refused.error.to_s
    grant_after_refusal = RecordingStudio::Recording.find(first_grant.id)
    authorization_after_refusal = RecordingStudioOauth::OauthAuthorization.find(second.value.fetch(:authorization).id)
    assert_equal "edit", authorization_after_refusal.role
    assert_equal "edit", grant_after_refusal.recordable.role
    assert grant_after_refusal.recording_studio_trashable_kept?
    assert_equal first_grant.id, authorization_after_refusal.access_recording_id
  end

  test "an admin can still connect" do
    admin = create_user(email: "admin-self-connect@example.com")
    root_recording, admin_access = create_access_recording_for(user: admin, role: :admin)

    result = connect_as(
      user: admin,
      oauth_client: @oauth_client,
      access_recording: admin_access,
      role: "admin"
    )

    assert result.success?, result.error.to_s
    granted = result.value.fetch(:access_recording)
    assert_equal "admin", granted.recordable.role
    assert_equal admin_access.id, granted.recordable.depends_on_recording_id
    assert RecordingStudioAccessible.authorized?(
      actor: result.value.fetch(:authorization),
      recording: root_recording,
      role: :admin
    )
  end

  test "an edit member can finish Connect in the browser" do
    editor = create_user(email: "edit-member-http@example.com")
    root_recording, edit_access = create_access_recording_for(user: editor, role: :edit)
    sign_in editor

    post authorize_path, params: authorize_params.merge(
      access_recording_id: edit_access.id,
      role: "edit",
      decision: "connect"
    )

    assert_response :redirect
    authorization = RecordingStudioOauth::OauthAuthorization.find_by!(
      oauth_client: @oauth_client,
      manager_actor: editor
    )
    assert_equal "edit", authorization.role
    assert_equal "edit", authorization.access_recording.recordable.role
    assert_equal edit_access.id, authorization.access_recording.recordable.depends_on_recording_id
    assert_equal root_recording.id, authorization.access_recording.parent_recording_id
    refute_includes response.body.to_s, "Not authorized to manage access"
  end

  private

  def connect_as(user:, oauth_client:, access_recording:, role:)
    previous_actor = Current.actor
    Current.actor = user
    RecordingStudioOauth::Services::CreateOauthAuthorization.call(
      oauth_client: oauth_client,
      manager_actor: user,
      access_recording: access_recording,
      role: role,
      redirect_uri: "http://127.0.0.1/callback",
      code_challenge: @pkce.fetch(:challenge),
      code_challenge_method: "S256"
    )
  ensure
    Current.actor = previous_actor
  end

  def authorize_path
    "/recording_studio_oauth/oauth/authorize"
  end

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
end
