# frozen_string_literal: true

require "test_helper"

class OauthMetricsApiTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers

  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"
  PUBLIC_ROOT = "/recording_studio_api/api/v1"

  setup do
    @staff = create_user(email: "metrics-staff-#{SecureRandom.hex(4)}@example.com")
    Current.actor = @staff
    @workspace_root, @workspace_access = create_access_recording_for(
      user: @staff,
      workspace_name: "Metrics #{SecureRandom.hex(4)}"
    )
    _admin_root, @admin_root_recording = create_admin_root_recording
    grant_or_bootstrap_access!(recording: @admin_root_recording, actor: @staff, role: :admin)

    seed_clients_and_authorizations!

    @staff_operations_token = provision_token(
      access_point: @admin_root_recording,
      actor: @staff,
      role: :edit,
      name: "Staff operations metrics #{SecureRandom.hex(4)}",
      api: :operations
    )
    @workspace_operations_token = provision_token(
      access_point: @workspace_root,
      actor: @staff,
      role: :edit,
      name: "Workspace operations metrics #{SecureRandom.hex(4)}",
      api: :operations
    )
    @public_token = provision_token(
      access_point: @workspace_root,
      actor: @staff,
      role: :view,
      name: "Public metrics #{SecureRandom.hex(4)}"
    )
    Current.actor = nil
  end

  teardown do
    Current.actor = nil
  end

  test "operations staff token reads oauth client and authorization metrics" do
    get "#{OPERATIONS_ROOT}/metrics/oauth_clients/total",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    assert_equal RecordingStudioOauth::OauthClient.active.count, response.parsed_body.fetch("value")

    get "#{OPERATIONS_ROOT}/metrics/oauth_clients/by_registration",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    registration_counts = breakdown_counts(response.parsed_body)
    active = RecordingStudioOauth::OauthClient.active
    assert_equal active.where(self_registered: true).count, registration_counts.fetch(true).to_i
    assert_equal active.where(self_registered: false).count, registration_counts.fetch(false).to_i
    assert_operator registration_counts.fetch(true).to_i, :>=, 1
    assert_operator registration_counts.fetch(false).to_i, :>=, 1

    get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/by_role",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    role_counts = breakdown_counts(response.parsed_body)
    RecordingStudioOauth::OauthAuthorization::ROLES.each do |role|
      assert_equal RecordingStudioOauth::OauthAuthorization.active.where(role: role).count, role_counts[role].to_i
    end

    get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/over_time",
        params: { interval: "day" },
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    opened = timeseries_counts(response.parsed_body)
    assert_equal authorizations_created_between(Time.utc(2026, 9, 20), Time.utc(2026, 9, 21)), opened["2026-09-20"]
    assert_equal authorizations_created_between(Time.utc(2026, 10, 5), Time.utc(2026, 10, 6)), opened["2026-10-05"]
    assert_operator opened["2026-09-20"], :>=, 1
    assert_operator opened["2026-10-05"], :>=, 1
  end

  test "metrics index lists oauth client and authorization metrics" do
    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@staff_operations_token), as: :json

    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    %w[
      oauth_clients.total
      oauth_clients.by_registration
      oauth_authorizations.over_time
      oauth_authorizations.by_role
    ].each { |identifier| assert_includes identifiers, identifier }
  end

  test "non-admin operations token is denied oauth metrics" do
    get "#{OPERATIONS_ROOT}/metrics/oauth_clients/total",
        headers: auth(@workspace_operations_token),
        as: :json
    assert_response :forbidden

    get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/by_role",
        headers: auth(@workspace_operations_token),
        as: :json
    assert_response :forbidden

    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@workspace_operations_token), as: :json
    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    refute_includes identifiers, "oauth_clients.total"
    refute_includes identifiers, "oauth_authorizations.by_role"
  end

  test "public API token is denied operations oauth metrics" do
    get "#{OPERATIONS_ROOT}/metrics/oauth_clients/total",
        headers: auth(@public_token),
        as: :json
    assert_response :unauthorized

    get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/over_time",
        headers: auth(@public_token),
        as: :json
    assert_response :unauthorized

    get "#{PUBLIC_ROOT}/metrics/oauth_clients/total",
        headers: auth(@public_token),
        as: :json
    assert_includes [404, 401, 403], response.status
  end

  private

  def seed_clients_and_authorizations!
    manual, = create_oauth_client(name: "Manual metrics #{SecureRandom.hex(4)}")
    dcr, = create_oauth_client(name: "DCR metrics #{SecureRandom.hex(4)}")
    dcr.update!(self_registered: true)
    revoked, = create_oauth_client(name: "Revoked metrics #{SecureRandom.hex(4)}")
    revoked.update!(self_registered: true)
    revoked.revoke!

    travel_to Time.utc(2026, 9, 20, 12) do
      RecordingStudioOauth::OauthAuthorization.create!(
        oauth_client: manual,
        manager_actor: @staff,
        manager_access_recording: @workspace_access,
        access_recording: @workspace_access,
        role: "view"
      )
    end

    travel_to Time.utc(2026, 10, 5, 12) do
      RecordingStudioOauth::OauthAuthorization.create!(
        oauth_client: dcr,
        manager_actor: @staff,
        manager_access_recording: @workspace_access,
        access_recording: @workspace_access,
        role: "edit"
      )
      revoked_grant = RecordingStudioOauth::OauthAuthorization.create!(
        oauth_client: revoked,
        manager_actor: @staff,
        manager_access_recording: @workspace_access,
        access_recording: @workspace_access,
        role: "admin"
      )
      revoked_grant.update!(revoked_at: Time.current)
    end
  end

  def breakdown_counts(payload)
    payload.fetch("data").to_h { |row| [cast_breakdown_key(row.fetch("key")), row.fetch("value")] }
  end

  def cast_breakdown_key(key)
    return key unless key.is_a?(String)
    return true if key == "true"
    return false if key == "false"

    key
  end

  def authorizations_created_between(start_at, end_at)
    RecordingStudioOauth::OauthAuthorization.where(created_at: start_at...end_at).count
  end

  def timeseries_counts(payload)
    payload.fetch("data").to_h { |row| [row.fetch("date").to_s, row.fetch("value")] }
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def provision_token(access_point:, actor:, role:, name:, api: :public)
    result = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_point,
      manager_actor: actor,
      role: role,
      name: name,
      api: api
    )
    raise result.error unless result.success?

    payload = result.value
    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: payload.fetch(:credential).oauth_client_id,
      client_secret: payload.fetch(:token),
      api: api
    )
    raise token_result.error unless token_result.success?

    token_result.value.fetch(:access_token)
  end
end
