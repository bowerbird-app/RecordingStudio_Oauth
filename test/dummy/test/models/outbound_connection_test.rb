# frozen_string_literal: true

require "test_helper"

class OutboundConnectionTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  setup do
    @user = create_user
    @root_recording, = create_access_recording_for(user: @user)
  end

  test "an active personal row requires a root" do
    row = RecordingStudioOauth::OutboundConnection.new(
      provider_key: "fake_drive",
      owner_actor: @user,
      connected_by: @user,
      access_token: "user-token",
      refresh_token: "user-refresh",
      status: "active",
      granted_scopes: ["files.read"]
    )

    refute row.valid?
    assert_includes row.errors[:base], "Connection must belong to a workspace or a person, not both"

    row.root_recording_id = @root_recording.id
    assert row.valid?
    assert row.user_owned?
    refute row.root_owned?
    assert_equal "user", row.owner_kind
  end

  test "leftover personal rows may omit a root when they are not active" do
    %w[needs_reconnect revoked].each do |status|
      row = RecordingStudioOauth::OutboundConnection.new(
        provider_key: "fake_drive",
        owner_actor: @user,
        connected_by: @user,
        access_token: status == "revoked" ? nil : "leftover-#{status}",
        refresh_token: status == "revoked" ? nil : "leftover-refresh-#{status}",
        status: status,
        granted_scopes: ["files.read"]
      )
      assert row.valid?, "expected leftover #{status} to be valid"
      assert row.user_owned?
      refute row.root_owned?
    end
  end

  test "a workspace-owned row still has a null person owner" do
    row = RecordingStudioOauth::OutboundConnection.new(
      provider_key: "fake_drive",
      root_recording_id: @root_recording.id,
      connected_by: @user,
      access_token: "root-token",
      refresh_token: "root-refresh",
      status: "active",
      granted_scopes: ["files.read"]
    )
    assert row.valid?
    assert row.root_owned?
    refute row.user_owned?
    assert_equal "root", row.owner_kind
  end
end
