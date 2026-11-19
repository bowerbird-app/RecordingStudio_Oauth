# frozen_string_literal: true

class AddPluginKeyToRecordingStudioOauthClients < ActiveRecord::Migration[8.1]
  def up
    add_column :recording_studio_oauth_clients, :plugin_key, :string unless column_exists?(:recording_studio_oauth_clients, :plugin_key)
    add_index :recording_studio_oauth_clients, :plugin_key unless index_exists?(:recording_studio_oauth_clients, :plugin_key)
  end

  def down
    remove_index :recording_studio_oauth_clients, :plugin_key if index_exists?(:recording_studio_oauth_clients, :plugin_key)
    remove_column :recording_studio_oauth_clients, :plugin_key if column_exists?(:recording_studio_oauth_clients, :plugin_key)
  end
end
