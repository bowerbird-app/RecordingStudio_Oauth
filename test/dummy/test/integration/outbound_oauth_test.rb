# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class OutboundOauthTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    @root_recording, = create_access_recording_for(user: @user)
    @viewer = create_user(email: "viewer-#{SecureRandom.hex(4)}@example.com")
    grant_view_or_edit_on_new_workspace!(recording: @root_recording, actor: @viewer, role: :view)
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "connect callback stores an encrypted workspace connection" do
    logs = capture_logs do
      follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    end

    connection = RecordingStudioOauth::OutboundConnection.find_by!(
      provider_key: "fake_drive",
      root_recording_id: @root_recording.id
    )
    assert_equal "active", connection.status
    assert connection.access_token.present?
    refute_equal connection.access_token, raw_ciphertext(connection, :access_token)
    refute_includes connection.inspect, connection.access_token
    refute_includes logs, connection.access_token
    refute session.to_hash.values.flatten.compact.any? { |value| value.to_s.include?(connection.access_token) }
    assert_nil session[:access_token]
    assert_nil session["refresh_token"]
    assert_equal "acct-demo", connection.external_account_id
  end

  test "user connection is stored for that person" do
    follow_connect!(owner: "user")

    connection = RecordingStudioOauth::OutboundConnection.find_by!(
      provider_key: "fake_drive",
      owner_actor: @user
    )
    assert connection.user_owned?
    assert_nil connection.root_recording_id
  end

  test "viewer cannot create a workspace connection" do
    sign_in @viewer

    get recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      owner: "root",
      root_recording_id: @root_recording.id,
      return_to: "/"
    }

    assert_response :redirect
    assert_match(/admin/i, flash[:alert].to_s)
    assert_equal 0, RecordingStudioOauth::OutboundConnection.where(root_recording_id: @root_recording.id).count
  end

  test "shared true roots are rejected" do
    shared = SharedRoot.create!(name: "Inbox #{SecureRandom.hex(4)}")
    shared_root = RecordingStudio.root_recording_for(shared)

    get recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      owner: "root",
      root_recording_id: shared_root.id,
      return_to: "/"
    }

    assert_response :redirect
    assert_match(/shared space/, flash[:alert].to_s)
    assert_equal 0, RecordingStudioOauth::OutboundConnection.where(root_recording_id: shared_root.id).count
  end

  test "refresh renews an expired token and marks needs_reconnect on failure" do
    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    connection = RecordingStudioOauth::OutboundConnection.find_by!(root_recording_id: @root_recording.id)
    old_token = connection.access_token
    connection.update!(expires_at: 1.minute.ago)

    refreshed = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_predicate refreshed, :present?
    refute_equal old_token, refreshed.access_token
    assert_equal "active", refreshed.status

    connection.reload
    connection.update!(refresh_token: FakeOauth::FAIL_REFRESH, expires_at: 1.minute.ago)
    failed = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_nil failed
    assert_equal "needs_reconnect", connection.reload.status
  end

  test "disconnect revokes and reconnect restores a live row" do
    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    connection = RecordingStudioOauth::OutboundConnection.find_by!(root_recording_id: @root_recording.id)

    delete recording_studio_oauth.outbound_connection_path(connection), params: { return_to: "/" }
    assert_response :redirect
    assert_equal "revoked", connection.reload.status
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)

    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    live = RecordingStudioOauth::OutboundConnection.live.find_by!(root_recording_id: @root_recording.id)
    assert_equal "active", live.status
    refute_equal connection.id, live.id
  end

  test "lookup prefers the actor user connection and hides other people's" do
    follow_connect!(owner: "user")
    user_connection = RecordingStudioOauth::OutboundConnection.find_by!(owner_actor: @user)

    sign_in @viewer
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer)

    sign_in @user
    found = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_equal user_connection.id, found.id
  end

  test "viewer can use a workspace connection and a stranger cannot" do
    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    connection = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_equal connection.id, RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer).id

    stranger = create_user(email: "stranger-#{SecureRandom.hex(4)}@example.com")
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: stranger)
  end

  test "viewer cannot disconnect a workspace connection" do
    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    connection = RecordingStudioOauth::OutboundConnection.find_by!(root_recording_id: @root_recording.id)
    sign_in @viewer

    delete recording_studio_oauth.outbound_connection_path(connection), params: { return_to: "/" }
    assert_response :redirect
    assert_match(/can.t change this connection/i, flash[:alert].to_s)
    assert_equal "active", connection.reload.status
  end

  test "inbound authorize route is unchanged" do
    assert_equal "/recording_studio_oauth/oauth/authorize", recording_studio_oauth.oauth_authorize_path
    assert_equal "/recording_studio_oauth/callback", recording_studio_oauth.central_oauth_callback_path
    assert_equal "/recording_studio_oauth/outbound/callback", recording_studio_oauth.outbound_callback_path
  end

  test "fake authorize rejects a redirect that is not the outbound callback" do
    get "/fake_oauth/authorize", params: {
      client_id: FakeOauth::CLIENT_ID,
      redirect_uri: "https://evil.test/steal",
      state: "nope"
    }

    assert_response :bad_request
    assert_equal "unknown redirect", response.body
  end

  private

  def follow_connect!(owner:, root_recording_id: nil)
    get recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      owner: owner,
      root_recording_id: root_recording_id,
      return_to: "/"
    }
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
  end

  def raw_ciphertext(connection, attribute)
    connection.attributes_before_type_cast[attribute.to_s]
  end

  def capture_logs
    io = StringIO.new
    original = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end
end
