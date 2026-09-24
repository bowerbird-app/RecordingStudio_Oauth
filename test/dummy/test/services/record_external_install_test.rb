# frozen_string_literal: true

require "test_helper"

class RecordExternalInstallTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  setup do
    @user = create_user
    @root_recording, = create_access_recording_for(user: @user)
    @client, = create_oauth_client(
      name: "Channel App",
      session_token_provider: "channel"
    )
  end

  test "creates an install without a workspace" do
    result = RecordingStudioOauth.record_external_install(
      client: @client,
      external_id: "store-123"
    )

    assert result.success?
    install = result.value
    assert_equal "channel", install.provider
    assert_equal "store-123", install.external_id
    assert_equal @client.id, install.oauth_client_id
    refute install.connected?
    assert_nil install.workspace
    assert_nil install.connected_by
  end

  test "a second upsert keeps the same row" do
    first = RecordingStudioOauth.record_external_install(
      client: @client,
      external_id: "Store-123"
    )
    second = RecordingStudioOauth.record_external_install(
      client: @client,
      external_id: "store-123"
    )

    assert first.success?
    assert second.success?
    assert_equal first.value.id, second.value.id
    assert_equal 1, RecordingStudioOauth::ExternalInstall.where(oauth_client: @client).count
  end

  test "connect binds a workspace without treating install as login" do
    RecordingStudioOauth.record_external_install(
      client: @client,
      external_id: "store-123"
    )

    result = RecordingStudioOauth.record_external_install(
      client: @client,
      external_id: "store-123",
      root_recording: @root_recording,
      connected_by: @user
    )

    assert result.success?
    install = result.value.reload
    assert install.connected?
    assert_equal @root_recording.id, install.root_recording_id
    assert_equal @root_recording.recordable, install.workspace
    assert_equal @user, install.connected_by
  end

  test "a later upsert does not clear a bound workspace" do
    RecordingStudioOauth.record_external_install(
      client: @client,
      external_id: "store-123",
      root_recording: @root_recording,
      connected_by: @user
    )

    result = RecordingStudioOauth.record_external_install(
      client: @client,
      external_id: "store-123"
    )

    install = result.value.reload
    assert_equal @root_recording.id, install.root_recording_id
    assert_equal @user, install.connected_by
  end

  test "the same external id can exist on two registered apps" do
    other, = create_oauth_client(name: "Other Channel", session_token_provider: "channel")

    first = RecordingStudioOauth.record_external_install(
      client: @client,
      external_id: "store-123"
    )
    second = RecordingStudioOauth.record_external_install(
      client: other,
      external_id: "store-123"
    )

    refute_equal first.value.id, second.value.id
  end

  test "rejects a blank channel" do
    bare, = create_oauth_client(name: "No Channel")

    result = RecordingStudioOauth.record_external_install(
      client: bare,
      external_id: "store-123"
    )

    assert result.failure?
    assert_equal "channel is required", result.error
  end
end
