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

  test "connected_user_count is active personal rows on that workspace" do
    other_root, = create_access_recording_for(user: @user, workspace_name: "Other #{SecureRandom.hex(4)}")
    second = create_user(email: "second-#{SecureRandom.hex(4)}@example.com")
    grant_view_or_edit_on_new_workspace!(recording: @root_recording, actor: second, role: :view)

    assert_equal 0, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: @root_recording)
    assert_equal 0, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: nil)
    assert_equal 0, RecordingStudioOauth.connected_user_count(provider: "", root: @root_recording)

    create_user_connection(actor: @user)
    assert_equal 1, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: @root_recording)

    create_user_connection(actor: second)
    assert_equal 2, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: @root_recording)

    create_root_connection(status: "active")
    assert_equal 2, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: @root_recording)

    create_user_connection(actor: @user, root: other_root)
    assert_equal 2, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: @root_recording)
    assert_equal 1, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: other_root)

    create_user_connection(actor: create_user(email: "reconnect-#{SecureRandom.hex(4)}@example.com"), status: "needs_reconnect")
    assert_equal 2, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: @root_recording)

    revoked_actor = create_user(email: "revoked-#{SecureRandom.hex(4)}@example.com")
    create_user_connection(actor: revoked_actor, status: "revoked")
    assert_equal 2, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: @root_recording)
    assert_equal 2, RecordingStudioOauth::Outbound.connected_user_count(provider: :fake_drive, root: @root_recording)
  end

  test "personal lookup requires view access and does not revoke the row" do
    connection = create_user_connection(actor: @viewer)
    access = access_recording_for(@viewer)

    found = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer)
    assert_equal connection.id, found.id
    assert_equal connection.id, live_user_owned(@viewer).id

    RecordingStudioTrashable.void_recording!(access)

    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer)
    assert_nil live_user_owned(@viewer)
    assert_equal "active", connection.reload.status
    assert connection.access_token.present?

    grant_view_or_edit_on_new_workspace!(recording: @root_recording, actor: @viewer, role: :view)

    restored = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer)
    assert_equal connection.id, restored.id
    assert_equal "active", connection.reload.status
  end

  test "workspace lookup still uses view access and does not revoke the row" do
    connection = create_root_connection
    access = access_recording_for(@viewer)

    found = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer)
    assert_equal connection.id, found.id

    RecordingStudioTrashable.void_recording!(access)

    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer)
    assert_equal connection.id, RecordingStudioOauth.connection_for(
      provider: :fake_drive,
      root: @root_recording,
      actor: @user
    ).id
    assert_equal "active", connection.reload.status

    grant_view_or_edit_on_new_workspace!(recording: @root_recording, actor: @viewer, role: :view)

    restored = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer)
    assert_equal connection.id, restored.id
  end

  test "leftover null-root personal rows are not returned for any root" do
    leftover = RecordingStudioOauth::OutboundConnection.create!(
      provider_key: "fake_drive",
      owner_actor: @user,
      connected_by: @user,
      access_token: "leftover-#{SecureRandom.hex(4)}",
      refresh_token: "leftover-refresh-#{SecureRandom.hex(4)}",
      status: "needs_reconnect",
      granted_scopes: ["files.read"]
    )
    other_root, = create_access_recording_for(user: @user, workspace_name: "Other leftover #{SecureRandom.hex(4)}")

    assert_nil leftover.root_recording_id
    assert leftover.user_owned?
    refute leftover.root_owned?
    assert_equal :missing, status_for(@user)
    assert_nil id_for(@user)
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: other_root, actor: @user)
    assert_equal 0, RecordingStudioOauth.connected_user_count(provider: :fake_drive, root: @root_recording)
  end

  test "combined_connection_status reports workspace and personal slots separately" do
    assert_equal(
      { workspace: :missing, personal: :missing },
      combined_for(@user)
    )

    root = create_root_connection
    user = create_user_connection(actor: @user, status: "needs_reconnect")

    assert_equal(
      { workspace: :active, personal: :needs_reconnect },
      combined_for(@user)
    )
    assert_equal(
      { workspace: :active, personal: :missing },
      combined_for(@viewer)
    )
    assert_equal :needs_reconnect, status_for(@user)
    assert_equal user.id, id_for(@user)
    assert_equal root.id, id_for(@viewer)
  end

  test "combined_connection_status is missing when the actor cannot view the root" do
    create_root_connection
    create_user_connection(actor: @user)
    stranger = create_user(email: "combined-stranger-#{SecureRandom.hex(4)}@example.com")

    assert_equal(
      { workspace: :missing, personal: :missing },
      combined_for(stranger)
    )
  end

  test "dummy registers a root provider and a user provider that share FakeOauth" do
    listed = RecordingStudioOauth.outbound_providers
    root = listed.find { |item| item.fetch(:key) == "fake_drive" }
    personal = listed.find { |item| item.fetch(:key) == "fake_drive_user" }

    assert_equal :root, root.fetch(:kind)
    assert_equal :user, personal.fetch(:kind)
    assert_equal FakeOauth, RecordingStudioOauth::Outbound.provider("fake_drive").http
    assert_equal FakeOauth, RecordingStudioOauth::Outbound.provider("fake_drive_user").http
    refute listed.any? { |item| item.key?(:client_secret) }
    refute_includes listed.inspect, FakeOauth::CLIENT_SECRET
  end

  test "root_owned finder does not return a personal row on that root" do
    create_user_connection(actor: @user)

    found = RecordingStudioOauth::Outbound::LiveConnection.root_owned(
      provider_key: "fake_drive",
      root: @root_recording,
      actor: @user
    )
    assert_nil found
    assert_equal :active, status_for(@user)
  end

  private

  def status_for(actor)
    RecordingStudioOauth.connection_status(provider: :fake_drive, root: @root_recording, actor: actor)
  end

  def id_for(actor)
    RecordingStudioOauth.connection_id_for(provider: :fake_drive, root: @root_recording, actor: actor)
  end

  def combined_for(actor)
    RecordingStudioOauth.combined_connection_status(provider: :fake_drive, root: @root_recording, actor: actor)
  end

  def live_user_owned(actor)
    RecordingStudioOauth::Outbound::LiveConnection.user_owned(
      provider_key: "fake_drive",
      actor: actor,
      root: @root_recording
    )
  end

  def access_recording_for(actor)
    RecordingStudioAccessible.access_recordings_for_actor(
      recording: @root_recording,
      actor: actor
    ).first
  end

  def create_user_connection(actor:, status: "active", root: @root_recording)
    RecordingStudioOauth::OutboundConnection.create!(
      provider_key: "fake_drive",
      owner_actor: actor,
      root_recording_id: root&.id,
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
