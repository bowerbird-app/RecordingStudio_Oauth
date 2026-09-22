# frozen_string_literal: true

class AddCentralRelayRulesToRecordingStudioOauthClients < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_oauth_clients, :use_central_relay, :boolean, null: false, default: false
    add_column :recording_studio_oauth_clients, :allowed_return_patterns, :jsonb, null: false, default: []
    add_column :recording_studio_oauth_clients, :exact_return_urls, :jsonb, null: false, default: []
  end
end
