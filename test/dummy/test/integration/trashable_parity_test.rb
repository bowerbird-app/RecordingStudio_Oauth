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

  test "actor_access_recordings excludes trashed access via additive kept_sql" do
    authorization = @approved.fetch(:authorization)
    granted = authorization.access_recording

    before = RecordingStudioOauth::Integration.actor_access_recordings(actor: @user).map(&:id)
    assert_includes before, @access_recording.id

    RecordingStudioOauth::Services::VoidOauthAuthorization.call(authorization: authorization)
    after = RecordingStudioOauth::Integration.actor_access_recordings(actor: @user).map(&:id)

    refute_includes after, granted.id
    assert_empty RecordingStudio::Recording.unscoped
                                           .where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
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

  test "kept_sql matches main where(trashed_at: nil) under default_scope; active does not" do
    granted = @approved.fetch(:access_recording)
    RecordingStudioTrashable.void_recording!(granted, time: Time.utc(2026, 10, 13, 12, 0, 0))
    assert granted.reload.recording_studio_trashable_trashed?

    host = Class.new(RecordingStudio::Recording) do
      def self.name = "OauthTrashableParityHostRecording"

      default_scope -> { where(trashed_at: nil) }
    end
    host.include(RecordingStudioTrashable::RecordingScopes)

    # Prior trashed_at filter (only trashed rows), then apply a kept filter — the
    # case where active's unscope diverges from main's additive where(trashed_at: nil).
    only_trashed = host.unscope(where: :trashed_at).where.not(trashed_at: nil)
    assert_includes only_trashed.pluck(:id), granted.id

    main_ids = only_trashed.where(trashed_at: nil).order(:id).pluck(:id)
    kept_sql_ids = only_trashed.where(host.recording_studio_trashable_kept_sql).order(:id).pluck(:id)
    active_ids = only_trashed.recording_studio_trashable_active.order(:id).pluck(:id)
    all_kept_ids = host.unscope(where: :trashed_at).where(trashed_at: nil).order(:id).pluck(:id)

    assert_equal main_ids, kept_sql_ids
    assert_empty main_ids
    assert_equal all_kept_ids, active_ids
    refute_equal main_ids, active_ids

    # Oauth integration base is unscoped + kept_sql (same additive filter as main).
    oauth_ids = RecordingStudio::Recording.unscoped
                                          .where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
                                          .where(id: only_trashed.select(:id))
                                          .order(:id)
                                          .pluck(:id)
    assert_equal main_ids, oauth_ids
  end
end
