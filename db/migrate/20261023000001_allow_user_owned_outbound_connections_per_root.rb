# frozen_string_literal: true

class AllowUserOwnedOutboundConnectionsPerRoot < ActiveRecord::Migration[8.1]
  TABLE = :recording_studio_oauth_outbound_connections

  NEW_OWNER_CHECK = <<~SQL.squish
    (
      (root_recording_id IS NOT NULL AND owner_actor_id IS NULL AND owner_actor_type IS NULL)
      OR
      (root_recording_id IS NOT NULL AND owner_actor_id IS NOT NULL AND owner_actor_type IS NOT NULL)
      OR
      (
        root_recording_id IS NULL
        AND owner_actor_id IS NOT NULL
        AND owner_actor_type IS NOT NULL
        AND status IN ('needs_reconnect', 'revoked')
      )
    )
  SQL

  OLD_OWNER_CHECK = <<~SQL.squish
    (root_recording_id IS NOT NULL AND owner_actor_id IS NULL AND owner_actor_type IS NULL)
    OR
    (root_recording_id IS NULL AND owner_actor_id IS NOT NULL AND owner_actor_type IS NOT NULL)
  SQL

  def up
    execute <<~SQL.squish
      UPDATE recording_studio_oauth_outbound_connections
      SET status = 'needs_reconnect'
      WHERE owner_actor_id IS NOT NULL
        AND root_recording_id IS NULL
        AND status = 'active'
    SQL

    remove_check_constraint TABLE, name: "chk_rs_oauth_outbound_owner"
    remove_index TABLE, name: "idx_rs_oauth_outbound_live_root"
    remove_index TABLE, name: "idx_rs_oauth_outbound_live_user"

    add_check_constraint TABLE, NEW_OWNER_CHECK, name: "chk_rs_oauth_outbound_owner"
    add_index TABLE,
              %i[provider_key root_recording_id],
              unique: true,
              where: "root_recording_id IS NOT NULL AND owner_actor_id IS NULL AND status IN ('active', 'needs_reconnect')",
              name: "idx_rs_oauth_outbound_live_root"
    add_index TABLE,
              %i[provider_key owner_actor_type owner_actor_id root_recording_id],
              unique: true,
              where: "owner_actor_id IS NOT NULL AND root_recording_id IS NOT NULL AND status IN ('active', 'needs_reconnect')",
              name: "idx_rs_oauth_outbound_live_user"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
