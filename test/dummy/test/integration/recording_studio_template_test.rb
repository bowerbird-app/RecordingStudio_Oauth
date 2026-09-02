# frozen_string_literal: true

require "test_helper"

class DummyHostTest < ActiveSupport::TestCase
  test "dummy app loads root switchable config and controller support" do
    assert_equal [ "all_workspaces" ], RecordingStudioRootSwitchable.configuration.scopes.keys
    assert_equal :application_layout, RecordingStudioRootSwitchable.configuration.layout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end

  test "dummy app validates recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal [ "AdminRoot", "Workspace" ], RecordingStudio.root_recordable_types.sort
    assert_equal [ "Workspace", "Folder" ], RecordingStudio.allowed_parent_types_for("Page")
  end

  test "dummy app schema keeps accessible grants and oauth tables" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    assert connection.table_exists?(:recording_studio_oauth_clients)
    assert connection.table_exists?(:recording_studio_oauth_authorizations)
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "dummy seeds use hierarchy idempotently and restore current actor" do
    Current.actor = nil

    load Rails.root.join("db/seeds.rb").to_s

    workspace = Workspace.find_by!(name: "Studio Workspace")
    docs_workspace = Workspace.find_by!(name: "Docs Workspace")
    folder = Folder.find_by!(name: "Product Docs")
    page = Page.find_by!(title: "Getting Started")
    admin_root = AdminRoot.find_by!(name: "Admin")
    oauth_client = RecordingStudioOauth::OauthClient.find_by!(name: "Seed Demo App")
    root_recording = RecordingStudio::Recording.find_by!(recordable: workspace)
    docs_root_recording = RecordingStudio::Recording.find_by!(recordable: docs_workspace)
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder)
    page_recording = RecordingStudio::Recording.find_by!(recordable: page)
    admin_recording = RecordingStudio::Recording.find_by!(recordable: admin_root)

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil docs_root_recording.parent_recording_id
    assert_nil admin_recording.parent_recording_id
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    refute oauth_client.confidential?
    assert_equal 2, Workspace.where(name: ["Studio Workspace", "Docs Workspace"]).count

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudioOauth::OauthClient.count } do
        load Rails.root.join("db/seeds.rb").to_s
      end
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end

  test "workspace and folder enable accessible and admin root is staff only" do
    workspace_source = File.read(Rails.root.join("app/models/workspace.rb"))
    folder_source = File.read(Rails.root.join("app/models/folder.rb"))

    refute_includes workspace_source, "Capabilities::Example"
    assert_includes workspace_source, "enable_capability(:accessible"
    assert_includes folder_source, "enable_capability(:accessible"

    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
    assert RecordingStudio.capability_enabled?(:accessible, for: Folder)
    refute RecordingStudio.capability_enabled?(:accessible, for: Page)
    assert RecordingStudio.capability_enabled?(:accessible, for: AdminRoot)
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end
end
