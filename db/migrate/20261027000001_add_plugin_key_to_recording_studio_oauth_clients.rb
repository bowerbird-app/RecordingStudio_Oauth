# frozen_string_literal: true

class AddPluginKeyToRecordingStudioOauthClients < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_oauth_clients, :plugin_key, :string
    add_index :recording_studio_oauth_clients, :plugin_key
  end
end
