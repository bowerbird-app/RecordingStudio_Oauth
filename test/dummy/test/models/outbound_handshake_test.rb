# frozen_string_literal: true

require "test_helper"
require "rake"

class OutboundHandshakeTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  setup do
    @user = create_user
    Current.actor = @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "stale covers consumed and expired rows and cleanup_stale deletes them" do
    pending = issue_handshake
    consumed = issue_handshake
    consumed.consume!
    expired = issue_handshake
    expired.update_columns(expires_at: 1.minute.ago)

    stale_ids = RecordingStudioOauth::OutboundHandshake.stale.pluck(:id)
    assert_includes stale_ids, consumed.id
    assert_includes stale_ids, expired.id
    refute_includes stale_ids, pending.id

    RecordingStudioOauth::OutboundHandshake.cleanup_stale
    refute RecordingStudioOauth::OutboundHandshake.exists?(consumed.id)
    refute RecordingStudioOauth::OutboundHandshake.exists?(expired.id)
    assert RecordingStudioOauth::OutboundHandshake.exists?(pending.id)
  end

  test "issue sanitizes a dirty return_to to slash" do
    handshake = issue_handshake(return_to: " /workspace")
    assert_equal "/", handshake.return_to
  end

  test "cleanup rake task is defined and deletes stale rows" do
    Rails.application.load_tasks
    assert Rake::Task.task_defined?("recording_studio_oauth:cleanup_outbound_handshakes")

    consumed = issue_handshake
    consumed.consume!
    Rake::Task["recording_studio_oauth:cleanup_outbound_handshakes"].reenable
    Rake::Task["recording_studio_oauth:cleanup_outbound_handshakes"].invoke

    refute RecordingStudioOauth::OutboundHandshake.exists?(consumed.id)
  end

  private

  def issue_handshake(return_to: "/")
    RecordingStudioOauth::OutboundHandshake.issue!(
      provider_key: "fake_drive",
      owner_kind: "user",
      actor: @user,
      return_to: return_to,
      pkce: true
    )
  end
end
