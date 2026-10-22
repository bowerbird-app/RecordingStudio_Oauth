# frozen_string_literal: true

class CreateRecordingStudioOauthOutboundConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_oauth_outbound_connections, id: :uuid do |t|
      t.string :provider_key, null: false
      t.uuid :root_recording_id
      t.string :owner_actor_type
      t.uuid :owner_actor_id
      t.string :connected_by_type, null: false
      t.uuid :connected_by_id, null: false
      t.string :external_account_id
      t.string :external_account_label
      t.jsonb :granted_scopes, null: false, default: []
      t.text :access_token, null: false
      t.text :refresh_token
      t.datetime :expires_at
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :recording_studio_oauth_outbound_connections, :provider_key
    add_index :recording_studio_oauth_outbound_connections, :status
    add_index :recording_studio_oauth_outbound_connections,
              %i[provider_key root_recording_id],
              unique: true,
              where: "root_recording_id IS NOT NULL AND status IN ('active', 'needs_reconnect')",
              name: "idx_rs_oauth_outbound_live_root"
    add_index :recording_studio_oauth_outbound_connections,
              %i[provider_key owner_actor_type owner_actor_id],
              unique: true,
              where: "owner_actor_id IS NOT NULL AND status IN ('active', 'needs_reconnect')",
              name: "idx_rs_oauth_outbound_live_user"
    add_check_constraint :recording_studio_oauth_outbound_connections,
                         "(root_recording_id IS NOT NULL AND owner_actor_id IS NULL AND owner_actor_type IS NULL) OR (root_recording_id IS NULL AND owner_actor_id IS NOT NULL AND owner_actor_type IS NOT NULL)",
                         name: "chk_rs_oauth_outbound_owner"
    add_check_constraint :recording_studio_oauth_outbound_connections,
                         "status IN ('active', 'needs_reconnect', 'revoked')",
                         name: "chk_rs_oauth_outbound_status"
  end
end
