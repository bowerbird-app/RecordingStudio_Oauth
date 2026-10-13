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
    # Void the user's own access recording — the Oauth grant's access_recording is
    # owned by the authorization actor, so it is never in this list.
    granted = @access_recording
    before = RecordingStudioOauth::Integration.actor_access_recordings(actor: @user).map(&:id)
    assert_includes before, granted.id

    RecordingStudioTrashable.void_recording!(granted, time: Time.utc(2026, 10, 13, 18, 0, 0))
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

  test "kept_sql matches main where(trashed_at: nil) under where.not(trashed_at: nil) default_scope; active does not" do
    granted = @approved.fetch(:access_recording)
    RecordingStudioTrashable.void_recording!(granted, time: Time.utc(2026, 10, 13, 12, 0, 0))
    assert granted.reload.recording_studio_trashable_trashed?

    host = Class.new(RecordingStudio::Recording) do
      def self.name = "OauthTrashableParityHostRecording"

      # Host default scope already limits to trashed rows — the case where
      # active's unscope diverges from main's additive where(trashed_at: nil).
      default_scope -> { where.not(trashed_at: nil) }
    end
    host.include(RecordingStudioTrashable::RecordingScopes)

    only_trashed = host.all
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

  test "real call sites keep additive filter under where.not(trashed_at: nil) default_scope" do
    kept_access = @access_recording
    _trashed_root, trashed_access = create_access_recording_for(
      user: @user,
      workspace_name: "Trashable Parity Trashed Workspace"
    )
    RecordingStudioTrashable.void_recording!(trashed_access, time: Time.utc(2026, 10, 13, 12, 0, 0))
    assert trashed_access.reload.recording_studio_trashable_trashed?
    assert kept_access.reload.recording_studio_trashable_kept?

    _admin_root, kept_admin = create_admin_root_recording(name: "Admin")
    assert kept_admin.recording_studio_trashable_kept?

    other_admin = AdminRoot.create!(name: "Trashable Parity Trashed Admin #{SecureRandom.hex(4)}")
    trashed_admin = RecordingStudio.root_recording_for(other_admin)
    RecordingStudioTrashable.void_recording!(trashed_admin, time: Time.utc(2026, 10, 13, 12, 30, 0))
    assert trashed_admin.reload.recording_studio_trashable_trashed?

    with_recording_default_scope(-> { where.not(trashed_at: nil) }) do
      # Integration / controller start from unscoped + kept_sql (same as main).
      ids = RecordingStudioOauth::Integration.actor_access_recordings(actor: @user).map(&:id)
      assert_includes ids, kept_access.id
      refute_includes ids, trashed_access.id

      admin_recording = RecordingStudioOauth::Admin::OauthClientsController.new.send(:admin_access_recording)
      assert_equal kept_admin.id, admin_recording.id
      refute_equal trashed_admin.id, admin_recording.id

      # Dummy resolver does not unscoped; additive kept_sql under where.not matches
      # main's where(trashed_at: nil) and returns no kept Admin root.
      assert_nil RecordingStudioAdmin.configuration.access_recording_resolver.call(nil)
    end

    # Control: without the hostile default_scope the resolver finds the kept Admin root.
    assert_equal kept_admin.id, RecordingStudioAdmin.configuration.access_recording_resolver.call(nil).id
  end

  private

  def with_recording_default_scope(scope_body)
    recording = RecordingStudio::Recording
    previous = recording.default_scopes.dup
    recording.send(:default_scope, scope_body)
    yield
  ensure
    recording.default_scopes = previous
  end
end
