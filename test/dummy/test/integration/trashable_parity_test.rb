# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class TrashableParityIntegrationTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    _root, @access_recording = create_access_recording_for(user: @user)
    @oauth_client, = create_oauth_client(name: "Trashable Parity App")
    @approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording
    )
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "void_oauth_authorization soft-voids access via void_recording! with update_columns semantics" do
    authorization = @approved.fetch(:authorization)
    granted = authorization.access_recording
    assert granted.recording_studio_trashable_kept?
    refute granted.recording_studio_trashable_trashed?

    time = Time.utc(2026, 10, 13, 18, 0, 0)
    result = RecordingStudioOauth::Services::VoidOauthAuthorization.call(
      authorization: authorization,
      time: time
    )

    assert result.success?
    granted.reload
    assert_equal time.to_i, granted.trashed_at.to_i
    assert_equal time.to_i, granted.updated_at.to_i
    assert granted.recording_studio_trashable_trashed?
    refute granted.recording_studio_trashable_kept?
    assert_empty RecordingStudio::Recording.recording_studio_trashable_active.where(id: granted.id)

    # Idempotent: already-trashed row is left alone (shared void_recording! early return).
    later = Time.utc(2026, 10, 14, 9, 0, 0)
    RecordingStudioOauth::Services::VoidOauthAuthorization.call(authorization: authorization.reload, time: later)
    granted.reload
    assert_equal time.to_i, granted.trashed_at.to_i
  end

  test "actor_access_recordings excludes trashed access via recording_studio_trashable_active" do
    authorization = @approved.fetch(:authorization)
    granted = authorization.access_recording

    before = RecordingStudioOauth::Integration.actor_access_recordings(actor: @user).map(&:id)
    assert_includes before, @access_recording.id

    RecordingStudioOauth::Services::VoidOauthAuthorization.call(authorization: authorization)
    after = RecordingStudioOauth::Integration.actor_access_recordings(actor: @user).map(&:id)

    refute_includes after, granted.id
    assert_empty RecordingStudio::Recording.unscoped
                                           .recording_studio_trashable_active
                                           .where(id: granted.id)
  end

  test "authorization active? uses trashable kept predicates" do
    authorization = @approved.fetch(:authorization)
    assert authorization.granted_access_recording_active?

    RecordingStudioTrashable.void_recording!(authorization.access_recording, time: Time.current)
    authorization.reload
    refute authorization.granted_access_recording_active?
    refute authorization.active?
  end
end
