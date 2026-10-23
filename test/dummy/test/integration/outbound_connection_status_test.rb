# frozen_string_literal: true

require "test_helper"

class OutboundConnectionStatusTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers

  setup do
    @user = create_user
    @root_recording, = create_access_recording_for(user: @user)
    @viewer = create_user(email: "viewer-#{SecureRandom.hex(4)}@example.com")
    grant_view_or_edit_on_new_workspace!(recording: @root_recording, actor: @viewer, role: :view)
  end

  test "missing when there is no live connection" do
    assert_equal :missing, status_for(@user)
    assert_nil id_for(@user)
  end

  test "user-owned active connection" do
    connection = create_user_connection(actor: @user)

    assert_equal :active, status_for(@user)
    assert_equal connection.id, id_for(@user)
    assert_equal :missing, status_for(@viewer)
    assert_nil id_for(@viewer)
  end

  test "user-owned needs_reconnect connection" do
    connection = create_user_connection(actor: @user, status: "needs_reconnect")

    assert_equal :needs_reconnect, status_for(@user)
    assert_equal connection.id, id_for(@user)
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
  end

  test "root-owned active connection" do
    connection = create_root_connection

    assert_equal :active, status_for(@user)
    assert_equal :active, status_for(@viewer)
    assert_equal connection.id, id_for(@user)
    assert_equal connection.id, id_for(@viewer)
  end

  test "root-owned needs_reconnect connection" do
    connection = create_root_connection(status: "needs_reconnect")

    assert_equal :needs_reconnect, status_for(@user)
    assert_equal :needs_reconnect, status_for(@viewer)
    assert_equal connection.id, id_for(@viewer)
  end

  test "actor without access gets missing for a root-owned connection" do
    create_root_connection
    stranger = create_user(email: "stranger-#{SecureRandom.hex(4)}@example.com")

    assert_equal :missing, status_for(stranger)
    assert_nil id_for(stranger)
  end

  test "status does not refresh an expired token" do
    connection = create_root_connection(expires_at: 1.minute.ago)
    token = connection.access_token

    assert_equal :active, status_for(@user)
    assert_equal token, connection.reload.access_token
    assert_equal "active", connection.status
  end

  test "user-owned needs_reconnect is reported even when a usable root connection exists" do
    root = create_root_connection
    user = create_user_connection(actor: @user, status: "needs_reconnect")

    assert_equal :needs_reconnect, status_for(@user)
    assert_equal user.id, id_for(@user)
    found = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_equal root.id, found.id
  end

  private

  def status_for(actor)
    RecordingStudioOauth.connection_status(provider: :fake_drive, root: @root_recording, actor: actor)
  end

  def id_for(actor)
    RecordingStudioOauth.connection_id_for(provider: :fake_drive, root: @root_recording, actor: actor)
  end

  def create_user_connection(actor:, status: "active")
    RecordingStudioOauth::OutboundConnection.create!(
      provider_key: "fake_drive",
      owner_actor: actor,
      connected_by: actor,
      access_token: "user-#{SecureRandom.hex(4)}",
      refresh_token: "user-refresh-#{SecureRandom.hex(4)}",
      status: status,
      granted_scopes: ["files.read"]
    )
  end

  def create_root_connection(status: "active", expires_at: nil)
    RecordingStudioOauth::OutboundConnection.create!(
      provider_key: "fake_drive",
      root_recording_id: @root_recording.id,
      connected_by: @user,
      access_token: "root-#{SecureRandom.hex(4)}",
      refresh_token: "root-refresh-#{SecureRandom.hex(4)}",
      status: status,
      expires_at: expires_at,
      granted_scopes: ["files.read"]
    )
  end
end
