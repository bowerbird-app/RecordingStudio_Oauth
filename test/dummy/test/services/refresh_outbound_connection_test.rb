# frozen_string_literal: true

require "test_helper"

class RefreshOutboundConnectionTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  setup do
    FakeOauth.reset!
    @user = create_user
    @root_recording, = create_access_recording_for(user: @user)
    Current.actor = @user
    result = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @user,
      owner_kind: "root",
      root: @root_recording,
      callback_url: "http://www.example.com/recording_studio_oauth/outbound/callback"
    )
    handshake = result.value.fetch(:handshake)
    code = FakeOauth.issue_code(
      access_token: "live-access",
      refresh_token: "live-refresh",
      user_id: "acct",
      email: "acct@test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    finish = RecordingStudioOauth::Services::FinishOutboundConnect.call(
      state: handshake.nonce,
      code: code,
      actor: @user,
      callback_url: "http://www.example.com/recording_studio_oauth/outbound/callback"
    )
    raise finish.error.inspect unless finish.success?

    @connection = finish.value.fetch(:connection)
    @connection.update!(expires_at: 1.minute.ago)
  end

  teardown do
    FakeOauth.reset!
    Current.actor = nil if defined?(Current)
  end

  test "a network error is transient and leaves status alone" do
    @connection.update!(refresh_token: FakeOauth::NETWORK_REFRESH, expires_at: 1.minute.ago)

    result = RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    refute result.success?
    assert_equal :transient, result.error
    assert_equal "active", @connection.reload.status
  end

  test "a database error is transient and leaves status alone" do
    @connection.define_singleton_method(:update!) do |*|
      raise ActiveRecord::ActiveRecordError, "write failed"
    end

    result = RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    refute result.success?
    assert_equal :save_failed, result.error
    assert_equal "active", RecordingStudioOauth::OutboundConnection.find(@connection.id).status
  end

  test "mark_reconnect no-ops when the row is revoked during refresh" do
    @connection.update!(refresh_token: FakeOauth::FAIL_REFRESH)
    during_refresh_mutate!(-> { revoke_row! }) do
      RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    end

    row = reload_row
    assert_equal "revoked", row.status
    assert_nil row.access_token
    assert_nil row.refresh_token
  end

  test "mark_reconnect no-ops when status moved during refresh" do
    @connection.update!(refresh_token: FakeOauth::FAIL_REFRESH)
    snapshot = row_snapshot
    during_refresh_mutate!(-> { @connection.update!(status: "needs_reconnect") }) do
      RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    end

    row = reload_row
    assert_equal "needs_reconnect", row.status
    assert_equal snapshot.fetch(:access_token), row.access_token
    assert_equal FakeOauth::FAIL_REFRESH, row.refresh_token
  end

  test "mark_reconnect no-ops when refresh_token rotated during refresh" do
    @connection.update!(refresh_token: FakeOauth::FAIL_REFRESH)
    snapshot = row_snapshot
    during_refresh_mutate!(-> { @connection.update!(refresh_token: "rotated-refresh") }) do
      RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    end

    row = reload_row
    assert_equal "active", row.status
    assert_equal snapshot.fetch(:access_token), row.access_token
    assert_equal "rotated-refresh", row.refresh_token
  end

  test "apply_token no-ops when the row is revoked during refresh" do
    during_refresh_mutate!(-> { revoke_row! }) do
      RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    end

    row = reload_row
    assert_equal "revoked", row.status
    assert_nil row.access_token
    assert_nil row.refresh_token
  end

  test "apply_token no-ops when status moved during refresh" do
    snapshot = row_snapshot
    during_refresh_mutate!(-> { @connection.update!(status: "needs_reconnect") }) do
      RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    end

    row = reload_row
    assert_equal "needs_reconnect", row.status
    assert_equal snapshot.fetch(:access_token), row.access_token
    assert_equal snapshot.fetch(:refresh_token), row.refresh_token
  end

  test "apply_token no-ops when refresh_token rotated during refresh" do
    snapshot = row_snapshot
    during_refresh_mutate!(-> { @connection.update!(refresh_token: "rotated-refresh") }) do
      RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    end

    row = reload_row
    assert_equal "active", row.status
    assert_equal snapshot.fetch(:access_token), row.access_token
    assert_equal "rotated-refresh", row.refresh_token
  end

  test "500 with invalid_grant is transient and leaves status active" do
    @connection.update!(refresh_token: FakeOauth::INVALID_GRANT_500_REFRESH)

    result = RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: @connection)
    refute result.success?
    assert_equal :transient, result.error
    assert_equal "active", @connection.reload.status
  end

  private

  def during_refresh_mutate!(mutator)
    original = FakeOauth.method(:call)
    FakeOauth.define_singleton_method(:call) do |url, params|
      mutator.call
      original.call(url, params)
    end
    yield
  ensure
    FakeOauth.singleton_class.send(:define_method, :call, original)
  end

  def revoke_row!
    @connection.update!(status: "revoked", access_token: nil, refresh_token: nil)
  end

  def reload_row
    RecordingStudioOauth::OutboundConnection.find(@connection.id)
  end

  def row_snapshot
    row = reload_row
    {
      status: row.status,
      access_token: row.access_token,
      refresh_token: row.refresh_token
    }
  end
end
