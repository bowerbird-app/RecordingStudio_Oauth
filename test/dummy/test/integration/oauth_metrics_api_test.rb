# frozen_string_literal: true

require "test_helper"

class OauthMetricsApiTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers

  REPORT_TIME = Time.utc(2026, 10, 6, 12)
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"
  PUBLIC_ROOT = "/recording_studio_api/api/v1"

  setup do
    travel_to REPORT_TIME
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

  test "operations staff token reads self-registered sign-ups over time" do
    get "#{OPERATIONS_ROOT}/metrics/oauth_clients/self_registered_over_time",
        params: { interval: "day" },
        headers: auth(@staff_operations_token),
        as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "oauth_clients.self_registered_over_time", body.fetch("metric")
    assert_equal "New self-registered apps", body.fetch("title")
    assert_equal "Apps that signed themselves up (dynamic client registration) in each period, by created_at. " \
                 "Revoked ones still count.", body.fetch("description")
    assert_equal "count", body.fetch("unit")
    assert_equal "records_created_during_period", body.fetch("metadata").fetch("semantics")

    counts = timeseries_counts(body)
    assert_equal 31, counts.size
    assert_equal "2026-09-06", counts.keys.first
    assert_equal "2026-10-06", counts.keys.last
    assert_equal 0, counts.fetch("2026-09-20")
    assert_equal 2, counts.fetch("2026-10-05")
    assert_equal 2, counts.values.sum
  end

  test "self-registered sign-ups take from, to and group_by confidential or api_key" do
    travel_to Time.utc(2026, 10, 1, 12) do
      5.times { |index| self_registered_client!("DCR public #{index}") }
      self_registered_client!("DCR confidential", confidential: true)
    end
    manual_window, = create_oauth_client(name: "Manual in window #{SecureRandom.hex(4)}")
    manual_window.update_column(:created_at, Time.utc(2026, 10, 1, 13))

    %w[confidential api_key].each do |field|
      get "#{OPERATIONS_ROOT}/metrics/oauth_clients/self_registered_over_time",
          params: { interval: "day", group_by: field, from: "2026-10-01", to: "2026-10-06" },
          headers: auth(@staff_operations_token),
          as: :json

      assert_response :success
      body = response.parsed_body
      assert_equal field, body.fetch("group_by")
      totals = timeseries_counts(body)
      assert_equal "2026-10-01", totals.keys.first
      assert_equal 6, totals.fetch("2026-10-01")
      assert_equal 2, totals.fetch("2026-10-05")
      groups = body.fetch("groups")
      other = body["other"]
      totals.each do |date, total|
        grouped = groups.sum { |row| series_value(row.fetch("data"), date) }
        grouped += series_value(other.fetch("data"), date) if other
        assert_equal total, grouped, "#{field} groups plus other equal the total on #{date}"
      end
      keys = groups.map { |row| cast_breakdown_key(row.fetch("key")) }
      if field == "confidential"
        assert_equal [false], keys, "public DCR apps (7) are kept; the single confidential one folds into other"
        assert other.present?
      else
        assert_equal ["public"], keys
      end
    end
  end

  test "self-registered sign-ups reject identifying group_by fields" do
    %w[name client_id redirect_uris self_registered].each do |field|
      get "#{OPERATIONS_ROOT}/metrics/oauth_clients/self_registered_over_time",
          params: { group_by: field },
          headers: auth(@staff_operations_token),
          as: :json
      assert_response :unprocessable_entity, field
    end
  end

  test "catalog lists unit, title, description and group_by for self-registered sign-ups" do
    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@staff_operations_token), as: :json

    assert_response :success
    entry = response.parsed_body.fetch("metrics").index_by { |row| row.fetch("identifier") }
                    .fetch("oauth_clients.self_registered_over_time")
    assert_equal "count", entry.fetch("unit")
    assert_equal "New self-registered apps", entry.fetch("title")
    assert_includes entry.fetch("description"), "dynamic client registration"
    assert_equal %w[confidential api_key], entry.fetch("group_by")
    assert_equal 5, entry.fetch("min_group_size")
    assert_equal true, entry.dig("date_range", "supported")
  end

  test "authorizations granted and revoked over time take from, to and group_by role" do
    window = { interval: "day", from: "2026-09-20", to: "2026-10-06" }

    get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/granted_over_time",
        params: window, headers: auth(@staff_operations_token), as: :json
    assert_response :success
    granted = response.parsed_body
    assert_equal "Authorizations granted", granted.fetch("title")
    assert_equal "count", granted.fetch("unit")
    assert granted.fetch("description").present?
    counts = timeseries_counts(granted)
    assert_equal "2026-09-20", counts.keys.first
    assert_equal 1, counts.fetch("2026-09-20")
    assert_equal 2, counts.fetch("2026-10-05")

    get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/revoked_over_time",
        params: window, headers: auth(@staff_operations_token), as: :json
    assert_response :success
    revoked = timeseries_counts(response.parsed_body)
    expected = RecordingStudioOauth::OauthAuthorization.where(revoked_at: Time.utc(2026, 10, 5)...Time.utc(2026, 10, 6)).count
    assert_operator expected, :>=, 1
    assert_equal expected, revoked.fetch("2026-10-05")
    assert_equal 0, revoked.fetch("2026-09-20")

    get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/revoked_over_time",
        params: window.merge(group_by: "role"), headers: auth(@staff_operations_token), as: :json
    assert_response :success
    assert_equal "role", response.parsed_body.fetch("group_by")
  end

  test "authorizations granted and revoked reject identifying group_by fields" do
    %w[granted_over_time revoked_over_time].each do |name|
      %w[oauth_client_id manager_actor_id access_recording_id].each do |field|
        get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/#{name}",
            params: { interval: "day", group_by: field }, headers: auth(@staff_operations_token), as: :json
        assert_response :unprocessable_entity, "#{name} #{field}"
      end
    end
  end

  test "non-admin operations token is denied granted and revoked authorizations" do
    %w[granted_over_time revoked_over_time].each do |name|
      get "#{OPERATIONS_ROOT}/metrics/oauth_authorizations/#{name}",
          params: { interval: "day" }, headers: auth(@workspace_operations_token), as: :json
      assert_response :forbidden, name
    end
  end

  test "metrics index lists oauth client and authorization metrics" do
    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@staff_operations_token), as: :json

    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    oauth_identifiers = identifiers.grep(/\Aoauth_/).sort
    assert_equal %w[
      oauth_authorizations.by_role
      oauth_authorizations.granted_over_time
      oauth_authorizations.over_time
      oauth_authorizations.revoked_over_time
      oauth_clients.by_registration
      oauth_clients.self_registered_over_time
      oauth_clients.total
    ], oauth_identifiers

    readme = File.read(RecordingStudioOauth::Engine.root.join("README.md"))
    oauth_identifiers.each do |identifier|
      path = "#{OPERATIONS_ROOT}/metrics/#{identifier.tr(".", "/")}"
      assert readme.include?(path), "README missing #{path}"
    end
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

    get "#{OPERATIONS_ROOT}/metrics/oauth_clients/self_registered_over_time",
        headers: auth(@workspace_operations_token),
        as: :json
    assert_response :forbidden

    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@workspace_operations_token), as: :json
    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    refute_includes identifiers, "oauth_clients.total"
    refute_includes identifiers, "oauth_authorizations.by_role"
    refute_includes identifiers, "oauth_clients.self_registered_over_time"
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
    manual = nil
    dcr = nil
    revoked = nil

    travel_to Time.utc(2026, 9, 20, 12) do
      manual, = create_oauth_client(name: "Manual metrics #{SecureRandom.hex(4)}")
      RecordingStudioOauth::OauthAuthorization.create!(
        oauth_client: manual,
        manager_actor: @staff,
        manager_access_recording: @workspace_access,
        access_recording: @workspace_access,
        role: "view"
      )
    end

    travel_to Time.utc(2026, 10, 5, 12) do
      dcr, = create_oauth_client(name: "DCR metrics #{SecureRandom.hex(4)}")
      dcr.update!(self_registered: true)
      revoked, = create_oauth_client(name: "Revoked metrics #{SecureRandom.hex(4)}")
      revoked.update!(self_registered: true)
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

    revoked.revoke!
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

  def self_registered_client!(label, confidential: false)
    client, = create_oauth_client(name: "#{label} #{SecureRandom.hex(4)}", confidential: confidential)
    client.update!(self_registered: true)
    client
  end

  def series_value(data, date)
    row = data.find { |entry| entry.fetch("date").to_s == date }
    row ? row.fetch("value") : 0
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
