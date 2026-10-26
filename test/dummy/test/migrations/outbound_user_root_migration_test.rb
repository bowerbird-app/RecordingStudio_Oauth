# frozen_string_literal: true

require "test_helper"
require RecordingStudioOauth::Engine.root.join(
  "db/migrate/20261023000001_allow_user_owned_outbound_connections_per_root"
).to_s

class OutboundUserRootMigrationTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  TABLE = :recording_studio_oauth_outbound_connections
  MIGRATION = AllowUserOwnedOutboundConnectionsPerRoot

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

    ActiveRecord::Migration.suppress_messages { MIGRATION.new.up }

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

    indexes = connection.indexes(TABLE)
    root_index = indexes.find { |index| index.name == "idx_rs_oauth_outbound_live_root" }
    user_index = indexes.find { |index| index.name == "idx_rs_oauth_outbound_live_user" }
    assert root_index
    assert user_index
    assert_includes root_index.where, "owner_actor_id IS NULL"
    assert_equal %w[provider_key owner_actor_type owner_actor_id root_recording_id], user_index.columns
    assert_includes user_index.where, "root_recording_id IS NOT NULL"
    owner_check = connection.check_constraints(TABLE).find { |item| item.name == "chk_rs_oauth_outbound_owner" }
    assert owner_check
    assert_includes owner_check.expression, "needs_reconnect"
  ensure
    restore_current_owner_check!
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

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
    drop_owner_indexes_and_check!
    connection.add_check_constraint(
      TABLE,
      MIGRATION::OLD_OWNER_CHECK,
      name: "chk_rs_oauth_outbound_owner"
    )
    connection.add_index(
      TABLE,
      %i[provider_key root_recording_id],
      unique: true,
      where: "root_recording_id IS NOT NULL AND status IN ('active', 'needs_reconnect')",
      name: "idx_rs_oauth_outbound_live_root"
    )
    connection.add_index(
      TABLE,
      %i[provider_key owner_actor_type owner_actor_id],
      unique: true,
      where: "owner_actor_id IS NOT NULL AND status IN ('active', 'needs_reconnect')",
      name: "idx_rs_oauth_outbound_live_user"
    )
  end

  def restore_current_owner_check!
    drop_owner_indexes_and_check!
    connection.add_check_constraint(
      TABLE,
      MIGRATION::NEW_OWNER_CHECK,
      name: "chk_rs_oauth_outbound_owner"
    )
    connection.add_index(
      TABLE,
      %i[provider_key root_recording_id],
      unique: true,
      where: "root_recording_id IS NOT NULL AND owner_actor_id IS NULL AND status IN ('active', 'needs_reconnect')",
      name: "idx_rs_oauth_outbound_live_root"
    )
    connection.add_index(
      TABLE,
      %i[provider_key owner_actor_type owner_actor_id root_recording_id],
      unique: true,
      where: "owner_actor_id IS NOT NULL AND root_recording_id IS NOT NULL AND status IN ('active', 'needs_reconnect')",
      name: "idx_rs_oauth_outbound_live_user"
    )
  end

  def drop_owner_indexes_and_check!
    connection.remove_check_constraint TABLE, name: "chk_rs_oauth_outbound_owner" if owner_check_exists?
    names = connection.indexes(TABLE).map(&:name)
    connection.remove_index TABLE, name: "idx_rs_oauth_outbound_live_root" if names.include?("idx_rs_oauth_outbound_live_root")
    return unless names.include?("idx_rs_oauth_outbound_live_user")

    connection.remove_index TABLE, name: "idx_rs_oauth_outbound_live_user"
  end

  def owner_check_exists?
    connection.check_constraints(TABLE).any? { |item| item.name == "chk_rs_oauth_outbound_owner" }
  end
end
