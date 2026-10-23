# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "uri"

class OutboundOauthTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    FakeOauth.reset!
    @user = create_user
    @root_recording, = create_access_recording_for(user: @user)
    @viewer = create_user(email: "viewer-#{SecureRandom.hex(4)}@example.com")
    grant_view_or_edit_on_new_workspace!(recording: @root_recording, actor: @viewer, role: :view)
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
    FakeOauth.reset!
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
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      "code" => "visible-oauth-code",
      "code_challenge" => "pkce-challenge",
      "country_code" => "NZ"
    )
    assert_equal "[FILTERED]", filtered["code"]
    assert_equal "pkce-challenge", filtered["code_challenge"]
    assert_equal "NZ", filtered["country_code"]
  end

  test "user connection is stored for that person" do
    follow_connect!(owner: "user", root_recording_id: @root_recording.id)

    connection = RecordingStudioOauth::OutboundConnection.find_by!(
      provider_key: "fake_drive",
      owner_actor: @user
    )
    assert connection.user_owned?
    assert_equal @root_recording.id, connection.root_recording_id
    assert_equal @user.id, connection.owner_actor_id
    refute connection.root_owned?
  end

  test "GET connect is rejected" do
    get recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      owner: "root",
      root_recording_id: @root_recording.id
    }

    assert_response :not_found
    assert_equal 0, RecordingStudioOauth::OutboundConnection.count
  end

  test "connect and disconnect without a CSRF token are rejected when forgery protection is on" do
    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    connection = RecordingStudioOauth::OutboundConnection.find_by!(root_recording_id: @root_recording.id)

    with_forgery_protection do
      post recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
        owner: "root",
        root_recording_id: @root_recording.id,
        return_to: "/"
      }
      assert_response :unprocessable_content
      assert_equal 1, RecordingStudioOauth::OutboundConnection.where(root_recording_id: @root_recording.id).count

      delete recording_studio_oauth.outbound_connection_path(connection), params: { return_to: "/" }
      assert_response :unprocessable_content
      assert_equal "active", connection.reload.status
    end
  end

  test "open redirect targets fall back to root and a workspace path is kept" do
    ["//evil", "/\\evil", "https://evil", "javascript:alert(1)"].each do |target|
      post recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
        owner: "root",
        root_recording_id: @root_recording.id,
        return_to: target
      }
      assert_response :redirect
      refute_includes response.redirect_url, "evil"
      refute_includes response.redirect_url, "javascript"
      query = authorize_query
      handshake = RecordingStudioOauth::OutboundHandshake.find_by_state(query.fetch("state"))
      assert_equal "/", handshake.return_to
    end

    follow_connect!(owner: "root", root_recording_id: @root_recording.id, return_to: "/workspace")
    assert_redirected_to "/workspace"
  end

  test "return_to with whitespace or control characters stores slash" do
    [" /workspace", "/workspace\n", "/workspace\t", "/workspace\u007F"].each do |target|
      post recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
        owner: "root",
        root_recording_id: @root_recording.id,
        return_to: target
      }
      assert_response :redirect
      handshake = RecordingStudioOauth::OutboundHandshake.find_by_state(authorize_query.fetch("state"))
      assert_equal "/", handshake.return_to
    end

    result = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @user,
      owner_kind: "user",
      root: @root_recording,
      callback_url: callback_url,
      return_to: " /workspace"
    )
    assert result.success?
    assert_equal "/", result.value.fetch(:handshake).return_to
  end

  test "viewer cannot create a workspace connection" do
    sign_in @viewer

    result = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @viewer,
      owner_kind: "root",
      root: @root_recording,
      callback_url: callback_url
    )

    refute result.success?
    assert_equal :not_admin, result.error
    assert_equal 0, RecordingStudioOauth::OutboundConnection.where(root_recording_id: @root_recording.id).count
  end

  test "shared true roots are rejected on start callback and lookup" do
    shared = SharedRoot.create!(name: "Inbox #{SecureRandom.hex(4)}")
    shared_root = RecordingStudio.root_recording_for(shared)

    result = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @user,
      owner_kind: "root",
      root: shared_root,
      callback_url: callback_url
    )

    refute result.success?
    assert_equal :shared_root, result.error
    assert_equal 0, RecordingStudioOauth::OutboundConnection.where(root_recording_id: shared_root.id).count

    user_start = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @user,
      owner_kind: "user",
      root: shared_root,
      callback_url: callback_url
    )
    refute user_start.success?
    assert_equal :shared_root, user_start.error

    handshake = RecordingStudioOauth::OutboundHandshake.issue!(
      provider_key: "fake_drive",
      owner_kind: "root",
      root_recording_id: shared_root.id,
      actor: @user,
      return_to: "/",
      pkce: true
    )
    code = FakeOauth.issue_code(
      access_token: "shared-access",
      refresh_token: "shared-refresh",
      user_id: "acct-shared",
      email: "shared@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    finish = assert_no_connection do
      finish_with(state: handshake.nonce, code: code)
    end
    assert_equal :shared_root, finish.error

    user_handshake = RecordingStudioOauth::OutboundHandshake.issue!(
      provider_key: "fake_drive",
      owner_kind: "user",
      root_recording_id: shared_root.id,
      actor: @user,
      return_to: "/",
      pkce: true
    )
    user_code = FakeOauth.issue_code(
      access_token: "shared-user-access",
      refresh_token: "shared-user-refresh",
      user_id: "acct-shared-user",
      email: "shared-user@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(user_handshake.code_verifier)
    )
    user_finish = assert_no_connection do
      finish_with(state: user_handshake.nonce, code: user_code)
    end
    assert_equal :shared_root, user_finish.error

    RecordingStudioOauth::OutboundConnection.create!(
      provider_key: "fake_drive",
      root_recording_id: shared_root.id,
      connected_by: @user,
      access_token: "live-shared",
      refresh_token: "live-shared-refresh",
      status: "active",
      granted_scopes: ["files.read"]
    )
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: shared_root, actor: @user)
  end

  test "non-root recordings are rejected on start, callback, and lookup" do
    folder_recording = create_folder_recording

    start_result = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @user,
      owner_kind: "root",
      root: folder_recording,
      callback_url: callback_url
    )
    refute start_result.success?
    assert_equal :invalid_root, start_result.error

    handshake = RecordingStudioOauth::OutboundHandshake.issue!(
      provider_key: "fake_drive",
      owner_kind: "root",
      root_recording_id: folder_recording.id,
      actor: @user,
      return_to: "/",
      pkce: true
    )
    code = FakeOauth.issue_code(
      access_token: "folder-access",
      refresh_token: "folder-refresh",
      user_id: "acct-folder",
      email: "folder@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    finish = RecordingStudioOauth::Services::FinishOutboundConnect.call(
      state: handshake.nonce,
      code: code,
      actor: @user,
      callback_url: callback_url
    )
    refute finish.success?
    assert_equal :invalid_root, finish.error
    assert_equal 0, RecordingStudioOauth::OutboundConnection.where(root_recording_id: folder_recording.id).count

    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    assert RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: folder_recording, actor: @user)
  end

  test "admin rights lost between start and callback create no connection" do
    root_recording, access_recording = create_access_recording_for(user: @user)
    start = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @user,
      owner_kind: "root",
      root: root_recording,
      callback_url: callback_url
    )
    assert start.success?
    handshake = start.value.fetch(:handshake)
    code = FakeOauth.issue_code(
      access_token: "lost-admin-access",
      refresh_token: "lost-admin-refresh",
      user_id: "acct-lost-admin",
      email: "lost-admin@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    RecordingStudioTrashable.void_recording!(access_recording)

    finish = assert_no_connection do
      finish_with(state: handshake.nonce, code: code)
    end
    assert_equal :not_admin, finish.error
  end

  test "authorize URL uses PKCE S256 and extra params cannot override reserved keys" do
    post recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      owner: "user",
      root_recording_id: @root_recording.id,
      return_to: "/"
    }
    assert_response :redirect
    query = authorize_query
    assert_equal "S256", query["code_challenge_method"]
    assert query["code_challenge"].present?
    refute query.key?("code_verifier")

    RecordingStudioOauth.register_outbound_provider(
      key: :drive_override,
      authorize_url: "https://example.test/auth",
      token_url: "https://example.test/token",
      client_id: "real-id",
      client_secret: "real-secret",
      extra_authorize_params: {
        redirect_uri: "https://evil.test/cb",
        state: "stolen",
        client_id: "spoof",
        response_type: "token",
        code_challenge: "plain-challenge",
        code_challenge_method: "plain",
        prompt: "consent"
      }
    )
    result = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "drive_override",
      actor: @user,
      owner_kind: "user",
      root: @root_recording,
      callback_url: "https://app.test/recording_studio_oauth/outbound/callback"
    )
    assert result.success?
    location = URI.parse(result.value.fetch(:location))
    query = URI.decode_www_form(location.query.to_s).to_h
    assert_equal "https://app.test/recording_studio_oauth/outbound/callback", query["redirect_uri"]
    refute_equal "stolen", query["state"]
    assert_equal "real-id", query["client_id"]
    assert_equal "code", query["response_type"]
    assert_equal "S256", query["code_challenge_method"]
    refute_equal "plain-challenge", query["code_challenge"]
    assert_equal "consent", query["prompt"]
    refute query.key?("code_verifier")
  end

  test "wrong missing replay expired and stolen handshakes create no connection" do
    assert_no_connection { finish_with(state: "missing-state", code: "any") }

    start_connect!(owner: "user", root_recording_id: @root_recording.id)
    query = authorize_query
    handshake = RecordingStudioOauth::OutboundHandshake.find_by_state(query.fetch("state"))
    code = FakeOauth.issue_code(
      access_token: "user-access",
      refresh_token: "user-refresh",
      user_id: "acct-user",
      email: "user@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    assert_no_connection { finish_with(state: "wrong-state", code: code) }

    start_connect!(owner: "user", root_recording_id: @root_recording.id)
    query = authorize_query
    follow_redirect!
    callback_uri = URI.parse(response.redirect_url)
    callback_params = Rack::Utils.parse_query(callback_uri.query)
    follow_redirect!
    assert_equal 1, RecordingStudioOauth::OutboundConnection.where(owner_actor: @user).count
    consumed = RecordingStudioOauth::OutboundHandshake.find_by_state(callback_params["state"])
    fresh_code = FakeOauth.issue_code(
      access_token: "replay-access",
      refresh_token: "replay-refresh",
      user_id: "acct-replay",
      email: "replay@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(consumed.code_verifier)
    )
    replay = assert_no_connection(from: 1) do
      finish_with(state: callback_params["state"], code: fresh_code)
    end
    assert_equal :invalid_state, replay.error

    start_connect!(owner: "user", root_recording_id: @root_recording.id)
    query = authorize_query
    handshake = RecordingStudioOauth::OutboundHandshake.find_by_state(query.fetch("state"))
    handshake.update_columns(expires_at: 1.minute.ago)
    follow_redirect!
    callback_uri = URI.parse(response.redirect_url)
    callback_params = Rack::Utils.parse_query(callback_uri.query)
    assert_no_connection(from: 1) do
      finish_with(state: callback_params["state"], code: callback_params["code"])
    end

    start_connect!(owner: "user", root_recording_id: @root_recording.id)
    follow_redirect!
    callback_uri = URI.parse(response.redirect_url)
    callback_params = Rack::Utils.parse_query(callback_uri.query)
    sign_in @viewer
    assert_no_connection(from: 1) do
      finish_with(state: callback_params["state"], code: callback_params["code"], actor: @viewer)
    end
  end

  test "missing or wrong PKCE verifier is rejected" do
    start_connect!(owner: "user", root_recording_id: @root_recording.id)
    query = authorize_query
    handshake = RecordingStudioOauth::OutboundHandshake.find_by_state(query.fetch("state"))
    code = FakeOauth.issue_code(
      access_token: "pkce-access",
      refresh_token: "pkce-refresh",
      user_id: "acct-pkce",
      email: "pkce@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    provider = RecordingStudioOauth::Outbound.provider("fake_drive")
    client = RecordingStudioOauth::Outbound::TokenClient.new(provider)

    missing = client.exchange_code(
      code: code,
      redirect_uri: callback_url,
      code_verifier: nil
    )
    refute missing.ok?
    assert_equal 400, missing.status

    replay_code = FakeOauth.issue_code(
      access_token: "pkce-access-2",
      refresh_token: "pkce-refresh-2",
      user_id: "acct-pkce",
      email: "pkce@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    wrong = client.exchange_code(
      code: replay_code,
      redirect_uri: callback_url,
      code_verifier: "a" * 43
    )
    refute wrong.ok?
    assert_equal 400, wrong.status
    assert_equal 0, RecordingStudioOauth::OutboundConnection.where(owner_actor: @user).count
  end

  test "refresh renews an expired token and marks needs_reconnect only on permanent oauth failures" do
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

    connection.update!(status: "active", refresh_token: FakeOauth::UNAUTHORIZED_CLIENT_REFRESH, expires_at: 1.minute.ago)
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_equal "needs_reconnect", connection.reload.status

    connection.update!(status: "active", refresh_token: FakeOauth::SERVER_ERROR_REFRESH, expires_at: 1.minute.ago)
    result = RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: connection)
    refute result.success?
    assert_equal :transient, result.error
    assert_equal "active", connection.reload.status

    connection.update!(status: "active", refresh_token: FakeOauth::INVALID_CLIENT_REFRESH, expires_at: 1.minute.ago)
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_equal "needs_reconnect", connection.reload.status

    connection.update!(status: "active", refresh_token: FakeOauth::INVALID_GRANT_500_REFRESH, expires_at: 1.minute.ago)
    grant_500 = RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: connection)
    refute grant_500.success?
    assert_equal :transient, grant_500.error
    assert_equal "active", connection.reload.status
  end

  test "a user connection in needs_reconnect falls through to a usable root connection" do
    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    follow_connect!(owner: "user", root_recording_id: @root_recording.id)
    user_connection = RecordingStudioOauth::OutboundConnection.find_by!(owner_actor: @user)
    root_connection = RecordingStudioOauth::OutboundConnection.find_by!(root_recording_id: @root_recording.id)
    user_connection.update!(status: "needs_reconnect")

    found = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    assert_equal root_connection.id, found.id
  end

  test "disconnect nulls tokens and reconnect restores a live row" do
    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    connection = RecordingStudioOauth::OutboundConnection.find_by!(root_recording_id: @root_recording.id)

    delete recording_studio_oauth.outbound_connection_path(connection), params: { return_to: "/" }
    assert_response :redirect
    assert_equal "revoked", connection.reload.status
    assert_nil connection.access_token
    assert_nil connection.refresh_token
    assert_nil RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)

    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    live = RecordingStudioOauth::OutboundConnection.live.find_by!(root_recording_id: @root_recording.id)
    assert_equal "active", live.status
    refute_equal connection.id, live.id
  end

  test "lookup prefers the actor user connection and hides other people's" do
    follow_connect!(owner: "user", root_recording_id: @root_recording.id)
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

  test "viewer cannot disconnect a workspace connection and a user connection stays owner-only" do
    follow_connect!(owner: "root", root_recording_id: @root_recording.id)
    root_connection = RecordingStudioOauth::OutboundConnection.find_by!(root_recording_id: @root_recording.id)
    follow_connect!(owner: "user", root_recording_id: @root_recording.id)
    user_connection = RecordingStudioOauth::OutboundConnection.find_by!(owner_actor: @user)

    viewer_root = RecordingStudioOauth::Services::DisconnectOutboundConnection.call(
      connection: root_connection,
      actor: @viewer
    )
    refute viewer_root.success?
    assert_equal :forbidden, viewer_root.error
    assert_equal "active", root_connection.reload.status

    viewer_user = RecordingStudioOauth::Services::DisconnectOutboundConnection.call(
      connection: user_connection,
      actor: @viewer
    )
    refute viewer_user.success?
    assert_equal :forbidden, viewer_user.error
    assert_equal "active", user_connection.reload.status
  end

  test "user connect without a root is rejected" do
    result = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @user,
      owner_kind: "user",
      callback_url: callback_url
    )
    refute result.success?
    assert_equal :root_required, result.error
    assert_equal 0, RecordingStudioOauth::OutboundConnection.count

    post recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      owner: "user",
      return_to: "/"
    }
    assert_response :redirect
    refute_includes response.redirect_url, "fake_oauth"
    assert_equal 0, RecordingStudioOauth::OutboundHandshake.count
  end

  test "the same person can connect the same provider on two roots" do
    other_root, = create_access_recording_for(user: @user, workspace_name: "Second #{SecureRandom.hex(4)}")
    follow_connect!(owner: "user", root_recording_id: @root_recording.id)
    follow_connect!(owner: "user", root_recording_id: other_root.id)

    first = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user)
    second = RecordingStudioOauth.connection_for(provider: :fake_drive, root: other_root, actor: @user)
    assert first.user_owned?
    assert second.user_owned?
    refute_equal first.id, second.id
    assert_equal @root_recording.id, first.root_recording_id
    assert_equal other_root.id, second.root_recording_id
    assert_equal first.id, RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @user).id
    refute_equal first.id, RecordingStudioOauth.connection_for(provider: :fake_drive, root: other_root, actor: @user).id
  end

  test "viewer can connect a personal row" do
    sign_in @viewer
    follow_connect!(owner: "user", root_recording_id: @root_recording.id)

    connection = RecordingStudioOauth::OutboundConnection.find_by!(owner_actor: @viewer)
    assert connection.user_owned?
    assert_equal @root_recording.id, connection.root_recording_id
    found = RecordingStudioOauth.connection_for(provider: :fake_drive, root: @root_recording, actor: @viewer)
    assert_equal connection.id, found.id
  end

  test "omitted owner with a root starts a personal handshake" do
    post recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      root_recording_id: @root_recording.id,
      return_to: "/"
    }
    assert_response :redirect
    handshake = RecordingStudioOauth::OutboundHandshake.find_by_state(authorize_query.fetch("state"))
    assert_equal "user", handshake.owner_kind
    assert_equal @root_recording.id, handshake.root_recording_id
    assert_equal 0, RecordingStudioOauth::OutboundConnection.count
  end

  test "successful personal connect revokes leftover null-root rows" do
    leftover = RecordingStudioOauth::OutboundConnection.create!(
      provider_key: "fake_drive",
      owner_actor: @user,
      connected_by: @user,
      access_token: "leftover-live",
      refresh_token: "leftover-live-refresh",
      status: "needs_reconnect",
      granted_scopes: ["files.read"]
    )
    follow_connect!(owner: "user", root_recording_id: @root_recording.id)

    leftover.reload
    assert_equal "revoked", leftover.status
    assert_nil leftover.access_token
    live = RecordingStudioOauth::OutboundConnection.find_by!(owner_actor: @user, root_recording_id: @root_recording.id)
    assert_equal "active", live.status
    refute_equal leftover.id, live.id
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
  end

  test "before_service receives the provider key not the handshake nonce" do
    original = RecordingStudio::Hooks.method(:run)
    start = RecordingStudioOauth::Services::StartOutboundConnect.call(
      provider: "fake_drive",
      actor: @user,
      owner_kind: "user",
      root: @root_recording,
      callback_url: callback_url
    )
    handshake = start.value.fetch(:handshake)
    code = FakeOauth.issue_code(
      access_token: "hook-access",
      refresh_token: "hook-refresh",
      user_id: "acct-hook",
      email: "hook@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    seen = nil
    RecordingStudio::Hooks.define_singleton_method(:run) do |event, *rest|
      if event == :before_service && rest.first == RecordingStudioOauth::Services::FinishOutboundConnect
        seen = rest.last
      end
      original.call(event, *rest)
    end
    finish = finish_with(state: handshake.nonce, code: code)
    assert finish.success?

    assert_equal "fake_drive", seen[:provider]
    refute_equal handshake.nonce, seen[:provider]
  ensure
    RecordingStudio::Hooks.singleton_class.send(:define_method, :run, original)
  end

  test "a consumed handshake that failed token exchange cannot be retried with a new code" do
    handshake = RecordingStudioOauth::OutboundHandshake.issue!(
      provider_key: "fake_drive",
      owner_kind: "user",
      root_recording_id: @root_recording.id,
      actor: @user,
      return_to: "/",
      pkce: true
    )
    failed = assert_no_connection do
      finish_with(state: handshake.nonce, code: "not-a-code")
    end
    assert_equal :token_exchange_failed, failed.error
    assert handshake.reload.consumed?

    retry_code = FakeOauth.issue_code(
      access_token: "retry-access",
      refresh_token: "retry-refresh",
      user_id: "acct-retry",
      email: "retry@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )
    retry_result = assert_no_connection do
      finish_with(state: handshake.nonce, code: retry_code)
    end
    assert_equal :invalid_state, retry_result.error
  end

  test "RecordNotUnique on create updates the live row" do
    klass = RecordingStudioOauth::Services::FinishOutboundConnect
    follow_connect!(owner: "user", root_recording_id: @root_recording.id)
    live = RecordingStudioOauth::OutboundConnection.find_by!(owner_actor: @user)
    handshake = RecordingStudioOauth::OutboundHandshake.issue!(
      provider_key: "fake_drive",
      owner_kind: "user",
      root_recording_id: @root_recording.id,
      actor: @user,
      return_to: "/",
      pkce: true
    )
    code = FakeOauth.issue_code(
      access_token: "unique-access",
      refresh_token: "unique-refresh",
      user_id: "acct-unique",
      email: "unique@fake-drive.test",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(handshake.code_verifier)
    )

    original_new = klass.method(:new)
    klass.define_singleton_method(:new) do |*args, **kwargs, &block|
      instance = original_new.call(*args, **kwargs, &block)
      instance.define_singleton_method(:live_connection) { |_handshake| nil }
      instance
    end
    result = finish_with(state: handshake.nonce, code: code)
    refute_equal :save_failed, result.error
    assert result.success?
    assert_equal live.id, result.value.fetch(:connection).id

    live.reload
    assert_equal "active", live.status
    assert_equal "unique-access", live.access_token
  ensure
    klass.singleton_class.send(:remove_method, :new) if klass.singleton_class.private_method_defined?(:new, false) || klass.singleton_class.method_defined?(:new, false)
  end

  test "callback url comes from the route helper" do
    post recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      owner: "user",
      root_recording_id: @root_recording.id,
      return_to: "/"
    }
    query = authorize_query
    assert_equal recording_studio_oauth.outbound_callback_url, query["redirect_uri"]
  end

  private

  def follow_connect!(owner:, root_recording_id: nil, return_to: "/")
    start_connect!(owner: owner, root_recording_id: root_recording_id, return_to: return_to)
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
  end

  def start_connect!(owner:, root_recording_id: nil, return_to: "/")
    post recording_studio_oauth.outbound_connect_path(provider: "fake_drive"), params: {
      owner: owner,
      root_recording_id: root_recording_id,
      return_to: return_to
    }
  end

  def authorize_query
    uri = URI.parse(response.redirect_url)
    URI.decode_www_form(uri.query.to_s).to_h
  end

  def finish_with(state:, code:, actor: @user)
    RecordingStudioOauth::Services::FinishOutboundConnect.call(
      state: state,
      code: code,
      actor: actor,
      callback_url: callback_url
    )
  end

  def callback_url
    "http://www.example.com/recording_studio_oauth/outbound/callback"
  end

  def assert_no_connection(from: 0)
    result = yield
    assert_respond_to result, :success?
    refute result.success?
    assert_equal from, RecordingStudioOauth::OutboundConnection.count
    result
  end

  def create_folder_recording
    folder = Folder.create!(name: "Folder #{SecureRandom.hex(4)}")
    RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: @root_recording,
      parent_recording: @root_recording
    ).recording
  end

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
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
