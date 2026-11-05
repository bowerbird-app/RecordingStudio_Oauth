# frozen_string_literal: true

require "test_helper"

class RecordingStudioWriteAuthorizationTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  test "dummy authorize_write allows a write when an actor is present" do
    authorizer = RecordingStudio.configuration.authorize_write

    assert_respond_to authorizer, :call
    user = create_user
    workspace = Workspace.create!(name: "Write auth #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.new(name: "Write auth folder #{SecureRandom.hex(4)}")

    event = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: user
    )

    assert_instance_of RecordingStudio::Event, event
    assert_equal user, event.actor
    assert_equal folder, event.recording.recordable
  end
end
