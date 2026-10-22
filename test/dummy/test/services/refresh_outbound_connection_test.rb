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
end
