# frozen_string_literal: true

require "test_helper"

class InboundConnectionStatusTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  setup do
    @admin = create_user
    @root, @admin_access = create_access_recording_for(user: @admin)
    @member = create_user(email: "member-#{SecureRandom.hex(4)}@example.com")
    @member_access = grant_or_bootstrap_access!(recording: @root, actor: @member, role: :admin)
    @viewer = create_user(email: "viewer-#{SecureRandom.hex(4)}@example.com")
    grant_view_or_edit_on_new_workspace!(recording: @root, actor: @viewer, role: :view)
    @client, = create_oauth_client(name: "Inbound App", plugin_key: "inbound_demo")
  end

  test "connected is true for the actor with a usable grant and count is admin-only" do
    connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)

    admin_status = status_for(@admin)
    assert_equal true, admin_status.fetch(:connected)
    assert_equal 1, admin_status.fetch(:connected_count)

    viewer_status = status_for(@viewer)
    assert_equal false, viewer_status.fetch(:connected)
    assert_nil viewer_status.fetch(:connected_count)

    connect_inbound!(oauth_client: @client, user: @member, access_recording: @member_access)
    assert_equal true, status_for(@member).fetch(:connected)
    assert_equal 2, status_for(@member).fetch(:connected_count)
    assert_equal 2, status_for(@admin).fetch(:connected_count)
    assert_nil status_for(@viewer).fetch(:connected_count)
  end

  test "blank or unknown plugin_key is disconnected" do
    connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)

    blank = RecordingStudioOauth.inbound_connection_status(plugin_key: "  ", root: @root, actor: @admin)
    assert_equal false, blank.fetch(:connected)
    assert_equal 0, blank.fetch(:connected_count)

    unknown = RecordingStudioOauth.inbound_connection_status(plugin_key: "missing_key", root: @root, actor: @admin)
    assert_equal false, unknown.fetch(:connected)
    assert_equal 0, unknown.fetch(:connected_count)

    viewer_blank = RecordingStudioOauth.inbound_connection_status(plugin_key: "", root: @root, actor: @viewer)
    assert_equal false, viewer_blank.fetch(:connected)
    assert_nil viewer_blank.fetch(:connected_count)
  end

  test "blank root is disconnected" do
    connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)

    status = RecordingStudioOauth.inbound_connection_status(plugin_key: "inbound_demo", root: nil, actor: @admin)
    assert_equal false, status.fetch(:connected)
    assert_nil status.fetch(:connected_count)
  end

  test "revoked authorization is not connected" do
    approved = connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)
    RecordingStudioOauth::Services::VoidOauthAuthorization.call(authorization: approved.fetch(:authorization))

    refute status_for(@admin).fetch(:connected)
    assert_equal 0, status_for(@admin).fetch(:connected_count)
  end

  test "an expired access token with a live refresh token is still connected" do
    approved = approve_delegated_oauth(oauth_client: @client, user: @admin, access_recording: @admin_access)
    issue_live_tokens!(
      approved.fetch(:authorization),
      access_expires_at: 1.hour.ago,
      refresh_expires_at: 30.days.from_now
    )

    assert status_for(@admin).fetch(:connected)
  end

  test "expired tokens are not connected" do
    approved = approve_delegated_oauth(oauth_client: @client, user: @admin, access_recording: @admin_access)
    issue_live_tokens!(
      approved.fetch(:authorization),
      access_expires_at: 1.hour.ago,
      refresh_expires_at: 1.hour.ago
    )

    refute status_for(@admin).fetch(:connected)
    assert_equal 0, status_for(@admin).fetch(:connected_count)
  end

  test "untrusted authorization is not connected" do
    approved = connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)
    RecordingStudioTrashable.void_recording!(approved.fetch(:authorization).access_recording)

    refute status_for(@admin).fetch(:connected)
    assert_equal 0, status_for(@admin).fetch(:connected_count)
  end

  test "losing view access hides the connection" do
    connect_inbound!(oauth_client: @client, user: @member, access_recording: @member_access)
    assert status_for(@member).fetch(:connected)

    RecordingStudioTrashable.void_recording!(@member_access)

    status = status_for(@member)
    assert_equal false, status.fetch(:connected)
    assert_nil status.fetch(:connected_count)
  end

  test "two clients under the same key both count distinct people" do
    other, = create_oauth_client(name: "Second Inbound App", plugin_key: "inbound_demo")
    connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)
    connect_inbound!(oauth_client: other, user: @member, access_recording: @member_access)

    assert_equal 2, status_for(@admin).fetch(:connected_count)
  end

  test "the same person through two clients counts once" do
    other, = create_oauth_client(name: "Second Inbound App", plugin_key: "inbound_demo")
    first = connect_inbound!(
      oauth_client: @client,
      user: @admin,
      access_recording: @admin_access,
      last_used_at: 2.days.ago
    )
    second = connect_inbound!(
      oauth_client: other,
      user: @admin,
      access_recording: @admin_access,
      role: "admin",
      last_used_at: 1.hour.ago
    )
    first.fetch(:authorization).update_columns(created_at: 3.days.ago)
    second.fetch(:authorization).update_columns(created_at: 1.day.ago)

    status = status_for(@admin)
    assert_equal true, status.fetch(:connected)
    assert_equal 1, status.fetch(:connected_count)

    people = RecordingStudioOauth.inbound_connections(plugin_key: "inbound_demo", root: @root, actor: @admin)
    assert_equal 1, people.size
    person = people.first
    assert_equal @admin.class.name, person.fetch(:actor_type)
    assert_equal @admin.id, person.fetch(:actor_id)
    assert_equal "admin", person.fetch(:role)
    assert_equal first.fetch(:authorization).reload.created_at.to_i, person.fetch(:connected_at).to_i
    assert_in_delta 1.hour.ago.to_i, person.fetch(:last_used_at).to_i, 2
    assert_equal "Inbound App, Second Inbound App", person.fetch(:app_name)
    refute_includes person.values.map(&:to_s).join, @admin.email
  end

  test "a different workspace does not leak" do
    other_root, other_access = create_access_recording_for(
      user: @admin,
      workspace_name: "Other #{SecureRandom.hex(4)}"
    )
    connect_inbound!(oauth_client: @client, user: @admin, access_recording: other_access)

    home = status_for(@admin)
    refute home.fetch(:connected)
    assert_equal 0, home.fetch(:connected_count)

    other = RecordingStudioOauth.inbound_connection_status(
      plugin_key: "inbound_demo",
      root: other_root,
      actor: @admin
    )
    assert other.fetch(:connected)
    assert_equal 1, other.fetch(:connected_count)
  end

  test "inbound_connections is admin-only and matches connected_count" do
    connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)
    connect_inbound!(oauth_client: @client, user: @member, access_recording: @member_access)

    admin_people = RecordingStudioOauth.inbound_connections(plugin_key: "inbound_demo", root: @root, actor: @admin)
    assert_equal 2, admin_people.size
    assert_equal status_for(@admin).fetch(:connected_count), admin_people.size
    assert_equal [ @admin.id, @member.id ].sort, admin_people.map { |row| row.fetch(:actor_id) }.sort

    assert_equal [], RecordingStudioOauth.inbound_connections(plugin_key: "inbound_demo", root: @root, actor: @viewer)

    stranger = create_user(email: "stranger-#{SecureRandom.hex(4)}@example.com")
    assert_equal [], RecordingStudioOauth.inbound_connections(plugin_key: "inbound_demo", root: @root, actor: stranger)
    stranger_status = status_for(stranger)
    assert_equal false, stranger_status.fetch(:connected)
    assert_nil stranger_status.fetch(:connected_count)
  end

  test "revoked client is not connected" do
    connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)
    @client.revoke!

    refute status_for(@admin).fetch(:connected)
    assert_equal 0, status_for(@admin).fetch(:connected_count)
    assert_equal [], RecordingStudioOauth.inbound_connections(plugin_key: "inbound_demo", root: @root, actor: @admin)
  end

  test "trashed access recording is not connected" do
    approved = connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)
    authorization = approved.fetch(:authorization)

    RecordingStudioTrashable.void_recording!(authorization.access_recording)

    refute authorization.reload.active?
    refute status_for(@admin).fetch(:connected)
    assert_equal 0, status_for(@admin).fetch(:connected_count)
  end

  test "trashed workspace is not connected" do
    approved = connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)
    authorization = approved.fetch(:authorization)

    RecordingStudioTrashable.void_recording!(@root)

    refute authorization.reload.active?
    refute status_for(@admin).fetch(:connected)
  end

  test "grant downgraded below the authorization role is not connected" do
    approved = connect_inbound!(
      oauth_client: @client,
      user: @admin,
      access_recording: @admin_access,
      role: "admin"
    )
    authorization = approved.fetch(:authorization)
    assert authorization.active?

    result = RecordingStudioAccessible::Services::UpdateRecordingAccess.call(
      recording: @root,
      access_recording: authorization.access_recording,
      role: :view,
      manager_actor: @admin
    )
    assert result.success?

    authorization.reload
    assert_equal "admin", authorization.role
    refute authorization.active?
    refute status_for(@admin).fetch(:connected)
    assert_equal 0, status_for(@admin).fetch(:connected_count)
  end

  test "dependent grant is not connected when its parent grant is trashed" do
    approved = connect_inbound!(oauth_client: @client, user: @member, access_recording: @member_access)
    authorization = approved.fetch(:authorization)
    assert_equal 1, status_for(@admin).fetch(:connected_count)

    RecordingStudioTrashable.void_recording!(@member_access)

    refute authorization.reload.active?
    refute status_for(@member).fetch(:connected)
    assert_equal 0, status_for(@admin).fetch(:connected_count)
    assert_equal [], RecordingStudioOauth.inbound_connections(plugin_key: "inbound_demo", root: @root, actor: @admin)
  end

  test "connected agrees with authorization.active? over seeded cases" do
    live = connect_inbound!(oauth_client: @client, user: @admin, access_recording: @admin_access)
    trashed_access = connect_inbound!(oauth_client: @client, user: @member, access_recording: @member_access)
    RecordingStudioTrashable.void_recording!(trashed_access.fetch(:authorization).access_recording)

    downgraded_user = create_user(email: "downgrade-#{SecureRandom.hex(4)}@example.com")
    downgraded_access = grant_or_bootstrap_access!(recording: @root, actor: downgraded_user, role: :admin)
    downgraded = connect_inbound!(
      oauth_client: @client,
      user: downgraded_user,
      access_recording: downgraded_access,
      role: "admin"
    )
    result = RecordingStudioAccessible::Services::UpdateRecordingAccess.call(
      recording: @root,
      access_recording: downgraded.fetch(:authorization).access_recording,
      role: :view,
      manager_actor: @admin
    )
    assert result.success?

    parent_user = create_user(email: "parent-#{SecureRandom.hex(4)}@example.com")
    parent_access = grant_or_bootstrap_access!(recording: @root, actor: parent_user, role: :admin)
    parent_trashed = connect_inbound!(
      oauth_client: @client,
      user: parent_user,
      access_recording: parent_access
    )
    RecordingStudioTrashable.void_recording!(parent_access)

    other_root, other_access = create_access_recording_for(
      user: @admin,
      workspace_name: "Parity other #{SecureRandom.hex(4)}"
    )
    other_workspace = connect_inbound!(oauth_client: @client, user: @admin, access_recording: other_access)

    seeded = [
      live.fetch(:authorization),
      trashed_access.fetch(:authorization),
      downgraded.fetch(:authorization),
      parent_trashed.fetch(:authorization),
      other_workspace.fetch(:authorization)
    ].map(&:reload)

    people = RecordingStudioOauth.inbound_connections(plugin_key: "inbound_demo", root: @root, actor: @admin)
    listed = people.map { |row| [ row.fetch(:actor_type), row.fetch(:actor_id).to_s ] }

    seeded.each do |authorization|
      next unless authorization.workspace_recording == @root

      in_people = listed.include?([ authorization.manager_actor_type, authorization.manager_actor_id.to_s ])
      assert_equal authorization.active?, in_people, "people list for authorization #{authorization.id}"
      assert_equal authorization.active?, status_for(authorization.manager_actor).fetch(:connected),
                   "connected for authorization #{authorization.id}"
    end

    assert_equal 1, people.size
    assert_equal @admin.id, people.first.fetch(:actor_id)
    refute_equal other_root.id, @root.id
    refute_equal other_workspace.fetch(:authorization).workspace_recording, @root
  end

  private

  def status_for(actor)
    RecordingStudioOauth.inbound_connection_status(plugin_key: "inbound_demo", root: @root, actor: actor)
  end
end
