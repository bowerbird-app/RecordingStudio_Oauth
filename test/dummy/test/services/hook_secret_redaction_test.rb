# frozen_string_literal: true

require "test_helper"

class HookSecretRedactionTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  SESSION = "dummy-session-secret"
  CLIENT_SECRET = "dummy-client-secret"
  AUTH_CODE = "dummy-auth-code-value"
  VERIFIER = "dummy-code-verifier-0123456789abcdefaaaaaaa"
  REFRESH = "dummy-refresh-token-value"
  ACCESS = "dummy-access-token-value"
  STATE = "dummy-state-value"
  STATE_SECRET = "dummy-state-secret"
  TOKEN = "dummy-session-token"
  SITE_STATE = "dummy-site-state"
  CHALLENGE = "dummy-code-challenge"
  CALLBACK = "http://www.example.com/recording_studio_oauth/outbound/callback"
  RELAY = "https://app.example.com/recording_studio_oauth/callback"
  RETURN_TO = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  PATTERN = "https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback"

  setup do
    clear_service_hooks
    FakeOauth.reset!
    @user = create_user
    @root_recording, @access_recording = create_access_recording_for(user: @user)
    Current.actor = @user
  end

  teardown do
    clear_service_hooks
  end

  test "authenticate hides the client secret on success and failure" do
    client, secret = create_oauth_client(confidential: true, session_token_secret: SESSION)
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::AuthenticateOauthClient.call(
        client_id: client.client_id,
        client_secret: secret
      )
    end

    assert result.success?, result.error.inspect
    assert_equal client.id, result.value.id
    assert_equal SESSION, result.value.session_token_secret
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::AuthenticateOauthClient, [secret, SESSION])
    hook_clients(payloads).each do |row|
      assert_nil row.session_token_secret
      assert_equal client.client_id, row.client_id
      refute_same client, row
    end

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::AuthenticateOauthClient.call(
        client_id: client.client_id,
        client_secret: CLIENT_SECRET
      )
    end

    assert failed.failure?
    assert_equal SESSION, client.reload.session_token_secret
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::AuthenticateOauthClient, [CLIENT_SECRET, SESSION])
  end

  test "resolve hides the session secret and still returns the client" do
    client, = create_oauth_client(session_token_secret: SESSION)
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::ResolveOauthClient.call(client_id: client.client_id)
    end

    assert result.success?, result.error.inspect
    assert_equal SESSION, result.value.session_token_secret
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::ResolveOauthClient, [SESSION])
    hook_clients(payloads).each { |row| assert_nil row.session_token_secret }

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::ResolveOauthClient.call(client_id: "dummy-missing-client")
    end

    assert failed.failure?
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::ResolveOauthClient, [SESSION])
  end

  test "create client hides the generated secret and the session secret" do
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::CreateOauthClient.call(
        name: "Dummy App",
        redirect_uris: ["http://127.0.0.1/callback"],
        confidential: true,
        session_token_secret: SESSION
      )
    end

    assert result.success?, result.error.inspect
    secret = result.value.fetch(:client_secret)
    assert secret.present?
    assert_equal SESSION, result.value.fetch(:client).session_token_secret
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::CreateOauthClient, [secret, SESSION])
    hook_clients(payloads).each do |row|
      assert_nil row.session_token_secret
      assert_equal result.value.fetch(:client).client_id, row.client_id
    end

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::CreateOauthClient.call(
        name: "",
        redirect_uris: ["http://127.0.0.1/callback"],
        confidential: false,
        session_token_secret: SESSION
      )
    end

    assert failed.failure?
    assert_equal SESSION, failed.errors.first.session_token_secret
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::CreateOauthClient, [SESSION])
  end

  test "update client hides a new session secret on success and when save fails" do
    client, = create_oauth_client
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::UpdateOauthClient.call(**update_args(client, name: "Renamed Dummy", session_token_secret: SESSION))
    end

    assert result.success?, result.error.inspect
    assert_equal SESSION, result.value.session_token_secret
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::UpdateOauthClient, [SESSION])
    hook_clients(payloads).each { |row| assert_nil row.session_token_secret }

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::UpdateOauthClient.call(**update_args(client, name: "", session_token_secret: SESSION))
    end

    assert failed.failure?
    assert_equal SESSION, failed.errors.first.session_token_secret
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::UpdateOauthClient, [SESSION])
  end

  test "register hides the issued client secret" do
    configuration = RecordingStudioOauth.configuration
    previous = configuration.allow_self_registered_apps
    configuration.allow_self_registered_apps = true
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::RegisterOauthClient.call(
        metadata: {
          "client_name" => "Dummy App",
          "redirect_uris" => ["http://127.0.0.1/callback"],
          "token_endpoint_auth_method" => "client_secret_post"
        }
      )
    end

    assert result.success?, result.error.inspect
    secret = result.value.fetch(:client_secret)
    assert secret.present?
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::RegisterOauthClient, [secret])

    configuration.allow_self_registered_apps = false
    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::RegisterOauthClient.call(
        metadata: {
          "client_name" => "Dummy App",
          "redirect_uris" => ["http://127.0.0.1/callback"],
          "client_secret" => CLIENT_SECRET
        }
      )
    end

    assert failed.failure?
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::RegisterOauthClient, [CLIENT_SECRET])
  ensure
    configuration&.allow_self_registered_apps = previous
  end

  test "prepare keeps public params and hides the rest" do
    client, = create_oauth_client(session_token_secret: SESSION)
    params = ActionController::Parameters.new(
      "client_id" => client.client_id,
      "redirect_uri" => "http://127.0.0.1/callback",
      "response_type" => "code",
      "code_challenge" => CHALLENGE,
      "code_challenge_method" => "S256",
      "state" => STATE,
      "client_secret" => CLIENT_SECRET,
      "code" => AUTH_CODE
    )
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::PrepareOauthAuthorize.call(params: params, actor: @user, base_url: "http://www.example.com")
    end

    assert result.success?, result.error.inspect
    assert_nil result.value[:halt]
    assert_equal STATE, result.value[:state]
    assert_equal CLIENT_SECRET, params["client_secret"]
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::PrepareOauthAuthorize, [STATE, CLIENT_SECRET, AUTH_CODE, SESSION])
    prepare_subjects(subjects).each do |subject|
      kept = subject.instance_variable_get(:@params)
      assert_equal client.client_id, kept["client_id"]
      assert_equal CHALLENGE, kept["code_challenge"]
      refute kept.key?("client_secret")
      refute kept.key?("code")
      refute kept.key?("state")
    end

    denied, denied_payloads, denied_subjects = capture do
      RecordingStudioOauth::Services::PrepareOauthAuthorize.call(
        params: ActionController::Parameters.new(params.to_unsafe_h.merge("response_type" => "token")),
        actor: @user,
        base_url: "http://www.example.com"
      )
    end

    assert denied.success?
    assert_equal "unsupported_response_type", denied.value[:halt][:error]
    assert_hidden(denied_payloads, denied_subjects, RecordingStudioOauth::Services::PrepareOauthAuthorize, [STATE, CLIENT_SECRET, AUTH_CODE, SESSION])
  end

  test "create authorization hides the issued code" do
    client, = create_oauth_client(session_token_secret: SESSION)
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::CreateOauthAuthorization.call(
        oauth_client: client,
        manager_actor: @user,
        access_recording: @access_recording,
        role: "view",
        redirect_uri: "http://127.0.0.1/callback",
        code_challenge: challenge_for(VERIFIER),
        code_challenge_method: "S256"
      )
    end

    assert result.success?, result.error.inspect
    code = result.value.fetch(:code)
    assert code.present?
    assert_equal SESSION, client.session_token_secret
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::CreateOauthAuthorization, [code, SESSION, VERIFIER])

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::CreateOauthAuthorization.call(
        oauth_client: client,
        manager_actor: nil,
        access_recording: @access_recording,
        role: "view",
        redirect_uri: "http://127.0.0.1/callback",
        code_challenge: challenge_for(VERIFIER)
      )
    end

    assert failed.failure?
    assert_equal SESSION, client.reload.session_token_secret
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::CreateOauthAuthorization, [SESSION, VERIFIER])
    hook_clients(failed_payloads).each { |row| assert_nil row.session_token_secret }
  end

  test "issue delegated token hides the code, verifier, and issued tokens" do
    client, = create_oauth_client
    approved = approve_delegated_oauth(
      oauth_client: client,
      user: @user,
      access_recording: @access_recording,
      pkce: { verifier: VERIFIER, challenge: challenge_for(VERIFIER) }
    )
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
        grant_type: "authorization_code",
        client_id: client.client_id,
        code: approved.fetch(:code),
        redirect_uri: approved.fetch(:redirect_uri),
        code_verifier: VERIFIER
      )
    end

    assert result.success?, result.error.inspect
    access = result.value.fetch(:access_token)
    refresh = result.value.fetch(:refresh_token)
    assert_equal "Bearer", result.value.fetch(:token_type)
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::IssueDelegatedAccessToken, [approved.fetch(:code), VERIFIER, access, refresh])
    issued = hook_hashes(payloads).select { |row| row.key?(:oauth_authorization_id) }
    assert_predicate issued, :any?
    issued.each do |row|
      assert_nil row[:access_token]
      assert_nil row[:refresh_token]
      assert_equal "Bearer", row[:token_type]
      assert_equal result.value.fetch(:oauth_authorization_id), row[:oauth_authorization_id]
    end

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::IssueDelegatedAccessToken.call(
        grant_type: "authorization_code",
        client_id: client.client_id,
        code: AUTH_CODE,
        redirect_uri: "http://127.0.0.1/callback",
        code_verifier: VERIFIER
      )
    end

    assert failed.failure?
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::IssueDelegatedAccessToken, [AUTH_CODE, VERIFIER])
  end

  test "verify session token hides the token and the secret" do
    client, = create_oauth_client(session_token_secret: SESSION, session_token_audience: "dummy-audience")
    now = Time.now.to_i
    token = RecordingStudioOauth::Hs256Jwt.encode(
      { "sub" => "dummy-user", "aud" => "dummy-audience", "exp" => now + 60, "nbf" => now - 5 },
      SESSION
    )
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::VerifySessionToken.call(token: token, client: client, now: now)
    end

    assert result.success?, result.error.inspect
    assert_equal "dummy-user", result.value.fetch(:claims).fetch("sub")
    assert_equal SESSION, result.value.fetch(:client).session_token_secret
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::VerifySessionToken, [token, SESSION])

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::VerifySessionToken.call(token: TOKEN, client: client, secret: SESSION, now: now)
    end

    assert failed.failure?
    assert_equal SESSION, client.reload.session_token_secret
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::VerifySessionToken, [TOKEN, SESSION])
  end

  test "record external install hides the client session secret" do
    client, = create_oauth_client(session_token_secret: SESSION, session_token_provider: "dummy")
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::RecordExternalInstall.call(client: client, external_id: "dummy-external", provider: "dummy")
    end

    assert result.success?, result.error.inspect
    assert_equal SESSION, result.value.oauth_client.session_token_secret
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::RecordExternalInstall, [SESSION])
    installs = records_of(payloads, RecordingStudioOauth::ExternalInstall)
    assert_predicate installs, :any?
    installs.each do |install|
      assert install.association(:oauth_client).loaded?
      assert_nil install.oauth_client.session_token_secret
      assert_equal client.id, install.oauth_client_id
    end

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::RecordExternalInstall.call(client: client, external_id: "", provider: "dummy")
    end

    assert failed.failure?
    assert_equal SESSION, client.reload.session_token_secret
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::RecordExternalInstall, [SESSION])
  end

  test "start and finish central relay hide the state secret and the code" do
    relay_client = relay_client_double
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::StartCentralRelay.call(
        client_id: "dummy-client-id",
        return_to: RETURN_TO,
        relay_callback_url: RELAY,
        code_challenge: CHALLENGE,
        site_state: SITE_STATE,
        state_secret: STATE_SECRET,
        resolve_client: ->(_id) { relay_client }
      )
    end

    assert result.success?, result.error.inspect
    ticket = result.value.fetch(:state)
    assert ticket.present?
    assert_equal "dummy-client-id", result.value.fetch(:client_id)
    assert_equal CHALLENGE, result.value.fetch(:code_challenge)
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::StartCentralRelay, [STATE_SECRET, SITE_STATE, ticket])

    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::StartCentralRelay.call(
        client_id: "dummy-client-id",
        return_to: RETURN_TO,
        relay_callback_url: RELAY,
        code_challenge: CHALLENGE,
        site_state: SITE_STATE,
        state_secret: STATE_SECRET,
        resolve_client: ->(_id) {}
      )
    end

    assert failed.failure?
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::StartCentralRelay, [STATE_SECRET, SITE_STATE])

    finished, finished_payloads, finished_subjects = capture do
      RecordingStudioOauth::Services::FinishCentralRelay.call(
        state: ticket,
        code: AUTH_CODE,
        state_secret: STATE_SECRET,
        resolve_client: ->(_id) { relay_client },
        find_authorization_code: ->(_code) { Struct.new(:code_challenge, :client_id).new(CHALLENGE, "dummy-client-id") }
      )
    end

    assert finished.success?, finished.error.inspect
    assert_includes finished.value.fetch(:location), AUTH_CODE
    assert_hidden(finished_payloads, finished_subjects, RecordingStudioOauth::Services::FinishCentralRelay, [STATE_SECRET, AUTH_CODE, ticket])

    forged, forged_payloads, forged_subjects = capture do
      RecordingStudioOauth::Services::FinishCentralRelay.call(
        state: STATE,
        code: AUTH_CODE,
        state_secret: STATE_SECRET,
        resolve_client: ->(_id) { relay_client }
      )
    end

    assert forged.failure?
    assert_hidden(forged_payloads, forged_subjects, RecordingStudioOauth::Services::FinishCentralRelay, [STATE_SECRET, AUTH_CODE, STATE])
  end

  test "outbound connect hides the handshake and the issued tokens" do
    started, started_payloads, started_subjects = capture do
      RecordingStudioOauth::Services::StartOutboundConnect.call(
        provider: "fake_drive",
        actor: @user,
        owner_kind: "root",
        root: @root_recording,
        callback_url: CALLBACK
      )
    end

    assert started.success?, started.error.inspect
    handshake = started.value.fetch(:handshake)
    assert handshake.code_verifier.present?
    assert_includes started.value.fetch(:location), handshake.nonce
    assert_hidden(started_payloads, started_subjects, RecordingStudioOauth::Services::StartOutboundConnect, [handshake.code_verifier, handshake.nonce])
    records_of(started_payloads, RecordingStudioOauth::OutboundHandshake).each do |row|
      assert_nil row.code_verifier
      assert_nil row.nonce
      refute_same handshake, row
    end

    unknown, unknown_payloads, unknown_subjects = capture do
      RecordingStudioOauth::Services::StartOutboundConnect.call(
        provider: "dummy-missing-provider",
        actor: @user,
        owner_kind: "root",
        root: @root_recording,
        callback_url: CALLBACK
      )
    end

    assert unknown.failure?
    assert_hidden(unknown_payloads, unknown_subjects, RecordingStudioOauth::Services::StartOutboundConnect, [])

    code = FakeOauth.issue_code(
      access_token: ACCESS,
      refresh_token: REFRESH,
      user_id: "dummy-account",
      email: "dummy@example.com",
      code_challenge: challenge_for(handshake.code_verifier)
    )
    finished, finished_payloads, finished_subjects = capture do
      RecordingStudioOauth::Services::FinishOutboundConnect.call(
        state: handshake.nonce,
        code: code,
        actor: @user,
        callback_url: CALLBACK
      )
    end

    assert finished.success?, finished.error.inspect
    connection = finished.value.fetch(:connection)
    assert_equal ACCESS, connection.access_token
    assert_equal REFRESH, connection.refresh_token
    assert_hidden(
      finished_payloads,
      finished_subjects,
      RecordingStudioOauth::Services::FinishOutboundConnect,
      [handshake.code_verifier, handshake.nonce, code, ACCESS, REFRESH]
    )
    hook_connections(finished_payloads).each do |row|
      assert_nil row.access_token
      assert_nil row.refresh_token
      assert_equal connection.id, row.id
      assert_equal ["files.read"], row.granted_scopes
      refute_same connection, row
    end

    missed, missed_payloads, missed_subjects = capture do
      RecordingStudioOauth::Services::FinishOutboundConnect.call(
        state: STATE,
        code: AUTH_CODE,
        actor: @user,
        callback_url: CALLBACK
      )
    end

    assert missed.failure?
    assert_hidden(missed_payloads, missed_subjects, RecordingStudioOauth::Services::FinishOutboundConnect, [STATE, AUTH_CODE])
  end

  test "lookup and refresh hide connection tokens and leave the row intact" do
    connection = connection_with(access_token: ACCESS, refresh_token: REFRESH, expires_at: 1.hour.from_now)
    result, payloads, subjects = capture do
      RecordingStudioOauth::Services::LookupOutboundConnection.call(provider: "fake_drive", root: @root_recording, actor: @user)
    end

    assert result.success?, result.error.inspect
    assert_equal ACCESS, result.value.access_token
    assert_equal connection.id, result.value.id
    assert_hidden(payloads, subjects, RecordingStudioOauth::Services::LookupOutboundConnection, [ACCESS, REFRESH])
    hook_connections(payloads).each do |row|
      assert_nil row.access_token
      assert_nil row.refresh_token
      assert_equal connection.id, row.id
      assert_equal ["files.read"], row.granted_scopes
      refute_same connection, row
    end

    empty, empty_payloads, empty_subjects = capture do
      RecordingStudioOauth::Services::LookupOutboundConnection.call(provider: "fake_drive", root: @root_recording, actor: nil)
    end

    assert empty.success?
    assert_nil empty.value
    assert_hidden(empty_payloads, empty_subjects, RecordingStudioOauth::Services::LookupOutboundConnection, [ACCESS, REFRESH])

    connection.update!(expires_at: 1.minute.ago)
    refreshed, refreshed_payloads, refreshed_subjects = capture do
      RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: connection)
    end

    assert refreshed.success?, refreshed.error.inspect
    issued = connection.reload.access_token
    assert issued.present?
    refute_equal ACCESS, issued
    assert_equal REFRESH, connection.refresh_token
    assert_hidden(refreshed_payloads, refreshed_subjects, RecordingStudioOauth::Services::RefreshOutboundConnection, [ACCESS, REFRESH, issued])

    connection.update!(access_token: ACCESS, refresh_token: FakeOauth::SERVER_ERROR_REFRESH, expires_at: 1.minute.ago, status: "active")
    failed, failed_payloads, failed_subjects = capture do
      RecordingStudioOauth::Services::RefreshOutboundConnection.call(connection: connection)
    end

    assert failed.failure?
    assert_equal :transient, failed.error
    assert_equal ACCESS, connection.reload.access_token
    assert_equal FakeOauth::SERVER_ERROR_REFRESH, connection.refresh_token
    assert_hidden(failed_payloads, failed_subjects, RecordingStudioOauth::Services::RefreshOutboundConnection, [ACCESS, FakeOauth::SERVER_ERROR_REFRESH])
  end

  test "disconnect hides tokens and does not clear them when disconnect is refused" do
    connection = connection_with(access_token: ACCESS, refresh_token: REFRESH)
    stranger = create_user
    refused, refused_payloads, refused_subjects = capture do
      RecordingStudioOauth::Services::DisconnectOutboundConnection.call(connection: connection, actor: stranger)
    end

    assert refused.failure?
    assert_equal :forbidden, refused.error
    assert_equal ACCESS, connection.reload.access_token
    assert_equal REFRESH, connection.refresh_token
    assert_hidden(refused_payloads, refused_subjects, RecordingStudioOauth::Services::DisconnectOutboundConnection, [ACCESS, REFRESH])
    hook_connections(refused_payloads).each do |row|
      assert_nil row.access_token
      assert_nil row.refresh_token
      refute_same connection, row
    end

    disconnected, disconnected_payloads, disconnected_subjects = capture do
      RecordingStudioOauth::Services::DisconnectOutboundConnection.call(connection: connection, actor: @user)
    end

    assert disconnected.success?, disconnected.error.inspect
    assert_nil connection.reload.access_token
    assert_hidden(disconnected_payloads, disconnected_subjects, RecordingStudioOauth::Services::DisconnectOutboundConnection, [ACCESS, REFRESH])
  end

  private

  def clear_service_hooks
    hooks = RecordingStudio.configuration.hooks
    hooks.clear(:after_service)
    hooks.clear(:around_service)
  end

  def capture
    payloads = []
    subjects = []
    hooks = RecordingStudio.configuration.hooks
    hooks.after_service { |_service_class, result| payloads << result }
    hooks.around_service do |subject, block|
      subjects << subject
      view = block.call
      payloads << view
      payloads << subject
      view
    end
    [yield, payloads, subjects]
  end

  def assert_hidden(payloads, subjects, klass, secrets)
    matched = subjects.select { |subject| subject.instance_of?(klass) }

    assert_predicate matched, :any?, "expected a #{klass} hook subject"
    matched.each { |subject| assert subject.is_a?(klass) }
    text = hook_text(payloads)
    secrets.compact.each do |secret|
      next if secret.length < 8

      refute_includes text, secret
    end
  end

  def hook_clients(payloads)
    records_of(payloads, RecordingStudioOauth::OauthClient)
  end

  def hook_connections(payloads)
    records_of(payloads, RecordingStudioOauth::OutboundConnection)
  end

  def hook_hashes(payloads)
    found = []
    walk(payloads) { |object| found << object if object.is_a?(Hash) }
    found
  end

  def prepare_subjects(subjects)
    subjects.select { |subject| subject.instance_of?(RecordingStudioOauth::Services::PrepareOauthAuthorize) }
  end

  def records_of(payloads, klass)
    found = []
    walk(payloads) { |object| found << object if object.is_a?(klass) }
    found
  end

  def hook_text(object)
    chunks = []
    walk(object) { |item| chunks << item if item.is_a?(String) }
    chunks.join("\n")
  end

  def walk(object, seen = {}.compare_by_identity, &block)
    return if object.nil? || seen[object]
    return if object.is_a?(Class) || object.is_a?(Module) || object.is_a?(Proc)
    return if defined?(ActiveRecord::Relation) && object.is_a?(ActiveRecord::Relation)

    seen[object] = true
    yield object
    case object
    when Hash
      object.each_value { |value| walk(value, seen, &block) }
    when Array
      object.each { |value| walk(value, seen, &block) }
    when RecordingStudio::Services::BaseService::Result
      walk(object.value, seen, &block)
      walk(object.error, seen, &block)
      walk(object.errors, seen, &block)
    else
      if object.class < RecordingStudio::Services::BaseService
        object.instance_variables.each { |name| walk(object.instance_variable_get(name), seen, &block) }
      elsif object.is_a?(ActiveRecord::Base)
        object.attributes.each_value { |value| walk(value, seen, &block) }
        secret_reader_values(object).each { |value| walk(value, seen, &block) }
        loaded_targets(object).each { |value| walk(value, seen, &block) }
      elsif parameters?(object)
        walk(object.to_unsafe_h, seen, &block)
      end
    end
  end

  def secret_reader_values(record)
    readers = {
      "RecordingStudioOauth::OutboundConnection" => %i[access_token refresh_token],
      "RecordingStudioOauth::OutboundHandshake" => %i[code_verifier nonce],
      "RecordingStudioOauth::OauthClient" => %i[session_token_secret]
    }[record.class.name]
    Array(readers).map { |name| record.public_send(name) }
  end

  def loaded_targets(record)
    return [] unless record.instance_variable_defined?(:@association_cache)

    record.instance_variable_get(:@association_cache).each_value.filter_map do |association|
      next unless association.respond_to?(:loaded?) && association.loaded?

      association.target
    end
  end

  def parameters?(object)
    defined?(ActionController::Parameters) && object.is_a?(ActionController::Parameters)
  end

  def challenge_for(verifier)
    RecordingStudioOauth::Pkce.s256_challenge(verifier)
  end

  def update_args(client, name:, session_token_secret:)
    {
      client: client,
      name: name,
      redirect_uris: client.redirect_uris,
      use_central_relay: client.use_central_relay,
      allowed_return_patterns: client.allowed_return_patterns,
      exact_return_urls: client.exact_return_urls,
      session_token_secret: session_token_secret
    }
  end

  def connection_with(access_token:, refresh_token:, expires_at: 1.hour.from_now)
    RecordingStudioOauth::OutboundConnection.create!(
      provider_key: "fake_drive",
      root_recording_id: @root_recording.id,
      connected_by: @user,
      access_token: access_token,
      refresh_token: refresh_token,
      status: "active",
      expires_at: expires_at,
      granted_scopes: ["files.read"]
    )
  end

  def relay_client_double
    client = Struct.new(
      :client_id,
      :api_key,
      :redirect_uris,
      :revoked,
      :use_central_relay,
      :allowed_return_patterns,
      :exact_return_urls,
      keyword_init: true
    ).new(
      client_id: "dummy-client-id",
      api_key: "public",
      redirect_uris: [RELAY],
      revoked: false,
      use_central_relay: true,
      allowed_return_patterns: [PATTERN],
      exact_return_urls: []
    )
    client.define_singleton_method(:revoked?) { revoked }
    client.define_singleton_method(:use_central_relay?) { use_central_relay }
    client.define_singleton_method(:redirect_uri_allowed?) { |uri| Array(redirect_uris).include?(uri) }
    client.define_singleton_method(:allows_return_to?) do |return_to|
      RecordingStudioOauth::ReturnUrlRules.allow?(return_to, patterns: allowed_return_patterns, exact_urls: exact_return_urls)
    end
    client
  end
end
