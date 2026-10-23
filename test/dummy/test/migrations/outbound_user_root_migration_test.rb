# frozen_string_literal: true

require "test_helper"
require RecordingStudioOauth::Engine.root.join(
  "db/migrate/20261023000001_allow_user_owned_outbound_connections_per_root"
).to_s

class OutboundUserRootMigrationTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  TABLE = :recording_studio_oauth_outbound_connections

  setup do
    @user = create_user
    @root_recording, = create_access_recording_for(user: @user)
  end

  test "active null-root personal rows become needs_reconnect and are not deleted" do
    restore_legacy_owner_check!
    active = insert_null_root_user_row!(status: "active", token: "legacy-active")
    already = insert_null_root_user_row!(
      status: "needs_reconnect",
      token: "legacy-reconnect",
      actor: create_user(email: "already-#{SecureRandom.hex(4)}@example.com")
    )
    revoked = insert_null_root_user_row!(
      status: "revoked",
      token: nil,
      actor: create_user(email: "revoked-#{SecureRandom.hex(4)}@example.com")
    )

    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      UPDATE recording_studio_oauth_outbound_connections
      SET status = 'needs_reconnect'
      WHERE owner_actor_id IS NOT NULL
        AND root_recording_id IS NULL
        AND status = 'active'
    SQL
    restore_current_owner_check!

    active.reload
    already.reload
    revoked.reload
    assert_equal "needs_reconnect", active.status
    assert_nil active.root_recording_id
    assert RecordingStudioOauth::OutboundConnection.exists?(active.id)
    assert_equal "needs_reconnect", already.status
    assert_equal "revoked", revoked.status
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_equal :missing, RecordingStudioOauth.connection_status(
      provider: :fake_drive,
      root: @root_recording,
      actor: @user
    )
    assert_nil RecordingStudioOauth.connection_id_for(
      provider: :fake_drive,
      root: @root_recording,
      actor: @user
    )
  ensure
    restore_current_owner_check!
  end

  private

  def insert_null_root_user_row!(status:, token:, actor: @user)
    row = RecordingStudioOauth::OutboundConnection.new(
      provider_key: "fake_drive",
      owner_actor: actor,
      connected_by: actor,
      access_token: token,
      refresh_token: token && "#{token}-refresh",
      status: status,
      granted_scopes: ["files.read"]
    )
    row.save!(validate: false)
    row
  end

  def restore_legacy_owner_check!
    connection = ActiveRecord::Base.connection
    connection.remove_check_constraint TABLE, name: "chk_rs_oauth_outbound_owner"
    connection.add_check_constraint(
      TABLE,
      AllowUserOwnedOutboundConnectionsPerRoot::OLD_OWNER_CHECK,
      name: "chk_rs_oauth_outbound_owner"
    )
  end

  def restore_current_owner_check!
    connection = ActiveRecord::Base.connection
    connection.remove_check_constraint TABLE, name: "chk_rs_oauth_outbound_owner"
    connection.add_check_constraint(
      TABLE,
      AllowUserOwnedOutboundConnectionsPerRoot::NEW_OWNER_CHECK,
      name: "chk_rs_oauth_outbound_owner"
    )
  end
end
