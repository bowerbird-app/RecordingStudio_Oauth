# frozen_string_literal: true

require "test_helper"
require RecordingStudioOauth::Engine.root.join(
  "db/migrate/20261119120001_add_plugin_key_to_recording_studio_oauth_clients"
).to_s

class PluginKeyMigrationTest < ActiveSupport::TestCase
  TABLE = :recording_studio_oauth_clients
  COLUMN = :plugin_key
  MIGRATION = AddPluginKeyToRecordingStudioOauthClients
  OLD_FILE = RecordingStudioOauth::Engine.root.join(
    "db/migrate/20261027000001_add_plugin_key_to_recording_studio_oauth_clients.rb"
  )
  NEW_FILE = RecordingStudioOauth::Engine.root.join(
    "db/migrate/20261119120001_add_plugin_key_to_recording_studio_oauth_clients.rb"
  )

  test "engine ships the renamed timestamp and not the colliding one" do
    refute File.exist?(OLD_FILE)
    assert File.exist?(NEW_FILE)
    refute File.exist?(Rails.root.join("db/migrate/#{OLD_FILE.basename}"))
    assert File.exist?(Rails.root.join("db/migrate/#{NEW_FILE.basename}"))
  end

  test "up is a no-op when plugin_key already exists" do
    assert connection.column_exists?(TABLE, COLUMN)
    assert connection.index_exists?(TABLE, COLUMN)

    ActiveRecord::Migration.suppress_messages { MIGRATION.new.up }

    assert connection.column_exists?(TABLE, COLUMN)
    assert connection.index_exists?(TABLE, COLUMN)
  end

  test "up adds a missing column and index and down removes what exists" do
    ActiveRecord::Migration.suppress_messages { MIGRATION.new.down }
    refute connection.column_exists?(TABLE, COLUMN)
    refute connection.index_exists?(TABLE, COLUMN)

    ActiveRecord::Migration.suppress_messages { MIGRATION.new.up }
    assert connection.column_exists?(TABLE, COLUMN)
    assert connection.index_exists?(TABLE, COLUMN)

    ActiveRecord::Migration.suppress_messages { MIGRATION.new.down }
    refute connection.column_exists?(TABLE, COLUMN)

    ActiveRecord::Migration.suppress_messages { MIGRATION.new.up }
    assert connection.column_exists?(TABLE, COLUMN)
    assert connection.index_exists?(TABLE, COLUMN)
  end

  private

  def connection
    ActiveRecord::Base.connection
  end
end
